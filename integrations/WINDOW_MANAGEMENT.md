# Window-management integration for MacStatusBar&Dock

This is a developer handoff, not an official upstream API or a binary release.
The reference integration targets upstream commit
[`2523e27a2f9fe65278b6e2e6bb3a5d84e8b0d757`](https://github.com/BesiktasliSeba/MacStatusBarAndDock/commit/2523e27a2f9fe65278b6e2e6bb3a5d84e8b0d757)
(1.7.4.1). Reconcile with the author's current source; do not overwrite a newer
core with an old build. Dock positioning is deliberately outside this handoff.

## Message to the upstream developer

> I'd like configurable hardware-keyboard shortcuts for Left/Right/Top/Bottom
> Half, quarters, Fill and real Home. KeyPilot already captures shortcuts and
> executes actions inside SpringBoard. Could you expose a small versioned C API
> from the initialized MacStatusBarCore payload, reusing your existing
> `DMWindowLayout` and `DMSMGoHomeForReal` implementation? This avoids automating
> the Window menu. The reference bridge and a window-only patch are included
> here. `fill` means maximize within the usable desktop, not native full-screen
> mode. New windows should default to Fill without the Fit-to-Window left/right
> question; explicit shortcut layouts should remain unchanged. Please retain
> your existing Dock implementation. These exported names were added by our
> local patch; they are not assumed to exist in your stock package.

## Architecture

```text
Magic Keyboard -> UIKit key-down hook (foreground app / SpringBoard)
  -> configured rule index via Darwin notification
  -> SpringBoard reloads and validates that rule, debounces, dispatches on main
  -> KeyPilot C-ABI client -> initialized MacStatusBarCore -> existing engine
```

`UIApplication.sendEvent:` observes `UIPressesEvent`, matches HID keyCode plus
modifiers and handles only `UIPressPhaseBegan`. Per-rule state is shared with
injected UIKit apps using notify state; actions themselves are read/executed in
SpringBoard, not in an arbitrary foreground app. See
[`Tweak.xm`](../KeyPilotHook/Tweak.xm). Direct-HID apps and apps excluding tweak
injection may not participate. There is no macOS Accessibility window API here.

This moves/resizes the **currently selected window**. It does not mean cycling
focus between different windows (Cmd+Tab / next window), and does not rearrange
all windows into a two-app split automatically.

## Versioned bridge contract

Implemented by [`MSBDKeyPilotBridge.inc`](MSBDKeyPilotBridge.inc), included at the
end of upstream `statusbar/StatusBar.x` in the same translation unit, because
the engine helpers are `static`. Functions have default symbol visibility.

```c
int MSBDKeyPilotLayoutV1(const char *layout);
int MSBDKeyPilotHomeV1(void);
int MSBDKeyPilotHomeEnvironmentV1(void);
```

All three are called in SpringBoard on the main thread. The layout bridge checks
the allowlist, lock/transition state, engine availability, active app and
full-screen-only restrictions before calling `DMWindowLayout(name)`.

| KeyPilot action | Bridge argument / function |
| --- | --- |
| `window:left-half`, `window:right-half` | `left`, `right` |
| `window:top-half`, `window:bottom-half` | `top`, `bottom` |
| `window:top-left`, `window:top-right` | `topleft`, `topright` |
| `window:bottom-left`, `window:bottom-right` | `bottomleft`, `bottomright` |
| `window:fill`, `window:center` | `fill`, `center` |
| `window:small`, `window:large` | `small`, `large` |
| `system:home` | `MSBDKeyPilotHomeV1()` |

Layout return codes: 0 dispatched, 1 wrong thread, 2 unknown layout, 3 no engine,
4 no active app, 5 full-screen-only app, 6 locked/workspace transitioning.
**0 is not proof that geometry changed**: the existing engine may complete
asynchronously or reject a later operation. A future V2 could add explicit
completion/geometry results without changing V1 semantics.

The client [`KPWindowController.m`](../KeyPilotHook/KPWindowController.m) uses
`dlsym` / `dlopen(..., RTLD_NOLOAD)`: it only queries an already loaded core;
it never initializes another copy or simulates menu clicks. If the bridge is
absent it logs failure, rather than silently clicking the UI. Example inside
SpringBoard's main queue:

```objc
void *h = dlopen("/var/jb/usr/lib/MacStatusBarAndDock/MacStatusBarCore.dylib",
                 RTLD_LAZY | RTLD_NOLOAD);
int (*layout)(const char *) = h ? dlsym(h, "MSBDKeyPilotLayoutV1") : NULL;
if (layout) {
    int status = layout("left"); // check status; dispatch != completed layout
    (void)status;
}
if (h) dlclose(h);
```

## Reuse the engine, not arbitrary UIView.frame writes

`DMWindowLayout` selects the active app and the applicable engine. In the pinned
source, Stage Manager uses `DMSMFrontWindowKey`, per-stage usable area,
`DMSMLayoutFrameIn`, then `DMSMSetWindowGeometry`. It subtracts the custom title
bar from the window rectangle and normalizes card size/center to that display.
Zetsu/Aerial/MilkyWay have separate move/convert-to-window paths. Reusing this
dispatch preserves engine-specific bookkeeping, minimum sizes, foreground
selection and explicit layout intent.

Usable area excludes the menu bar/Dock and uses the window's display where
supported by the engine. Left/right split that area with the engine's tile gap
(6 pt in the pinned source), rather than splitting raw screen pixels. Multiwindow
apps must target a window key, not only a bundle ID.

`fill` fills the usable desktop **while remaining a window**. It is not a
native full-screen transition. A separate native-full-screen action is not
exposed by this V1 allowlist; the author should expose their existing engine
transition as a separate action if wanted, not alias it to `fill`.

## Real Home (Command+H)

A simulated Home press alone was insufficient with the engine's keep-desktop
policy. The bridge minimizes visible custom native windows, calls
`DMSMGoHomeForReal` for Stage Manager, and otherwise uses the engine's minimize
paths. The existing `SMHome.h` implementation makes an engine-marked real-Home
workspace request (`SBHomeScreenEntity`, `requestTransitionWithBuilder:`),
coordinates gesture transitions and preserves its own guarded fallback. Reuse
that helper rather than duplicating unguarded private selectors.

`MSBDKeyPilotHomeV1` returns 0 dispatched, 1 wrong thread, 6 locked. After 1.5 s
KeyPilot reads `MSBDKeyPilotHomeEnvironmentV1`: 1 Home, 2 App Switcher, 3 App,
-1 unknown/wrong thread, -2 locked. Home is not app termination; existing app
processes remain available. Delayed transitions can require later verification.

## Default Fill without the side-selection question

The optional policy changes in the window-only patch disable `DMFitEnabled`
(local policy), default newly adopted Zetsu/Aerial windows to Fill, and set
Stage Manager desktop-join geometry to Fill. Explicit requested frames and
subsequent shortcut geometry remain under the engine's normal intent handling.
For upstream, make this a user preference rather than permanently forcing the
global Fit toggle off. Apply it at window adoption/join, **not every layout pass**,
otherwise later Left/Right shortcuts would immediately be overwritten.

## Source patch and build boundary

[`MSBD-1.7.4.1-window-only.patch`](MSBD-1.7.4.1-window-only.patch) contains only
the default-Fill policy and bridge include, with **no Dock hooks or geometry
reservation**. It is a reference for the pinned commit, not a patch promised to
apply to the latest upstream version. Place this repository's integration
folder around the source tree as follows, then apply from the source root:

```text
integrations/
  MSBDKeyPilotBridge.inc
  macstatusbar-src/statusbar/StatusBar.x
```

```sh
git apply --check ../MSBD-1.7.4.1-window-only.patch
git apply ../MSBD-1.7.4.1-window-only.patch
# With Theos, iPhoneOS SDK and upstream's private-framework link stubs configured:
make -C statusbar all FINALPACKAGE=1 SUBPROJECTS= TARGET=iphone:clang:18.2:15.0
```

The bridge/patch are GPL-3.0-only with upstream (see
[`COPYING.MacStatusBarAndDock`](COPYING.MacStatusBarAndDock)); the standalone
KeyPilot sources remain under their existing MIT license. This repository
publishes source and patch, not the upstream/custom dylib. Upstream source and
its notices must accompany any redistribution as required by its license.

## Verification and limits

Historical M1/iPadOS 17.0 tests logged direct Left/Right/Fill dispatch. Real Home
was additionally confirmed by environment readback and user feedback. This does
not certify all engines/layouts, native full-screen, external displays or the
author's newer builds. Check actual window bounds, focus, typing, repeated key
presses, multiwindow apps, lock screen, rotation and ongoing gestures. Back up
only the third-party payload being replaced and keep a safe-mode rollback path.
This handoff does not install anything or alter iPad system/boot files.

Suggested user-configurable bindings: Ctrl+Option+Left/Right -> Left/Right Half;
Ctrl+Option+Up -> Fill; Command+H -> Home. The layout bindings are examples,
not automatically seeded defaults. Command+H is seeded once by the local build.

中文要点：复用作者现有窗口引擎，在 SpringBoard 主线程导出版本化 C 接口；
KeyPilot 只负责快捷键和调用。`fill` 是窗口填满可用区域，不是原生全屏。
真正返回桌面要走引擎的 real-Home 路径，避免被“保留桌面窗口”策略改写。
