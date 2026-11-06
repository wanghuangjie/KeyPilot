# Changelog

## 0.4.3 (local integration)

- Published window-management source and an English developer handoff with a window-only upstream patch; no new binary release or Dock experiment is included.
- Fixed Command+H being rewritten by MacStatusBar&Dock's "keep windows at Home" policy. Uses the engine's real-Home transition through `MSBDKeyPilotHomeV1`.
- Added read-only Home environment confirmation after the transition; a dispatch alone is no longer considered a successful Home result.

## 0.4.2 (local integration)

- New Stage Manager windows join at Fill geometry; automatic Fit-to-Window tiling and its left/right question are disabled in the custom core.
- Added `system:home` and a one-time Command+H default rule, editable in the rule list.
- New Aerial/Zetsu stages also default to Fill; explicit requested layouts and existing stage intents are retained.

## 0.4.1 (local integration)

- Replaced Window menu automation with the versioned `MSBDKeyPilotLayoutV1` bridge in a custom MacStatusBarCore 1.7.4.1 build.
- Does not display the Window menu or require its button to be visible.
- Verified direct left-half, right-half and fill dispatch on the M1 iPad / iPadOS 17.0. Original core backed up before installation.

## 0.4.0 (unreleased)

- Added optional MacStatusBar&Dock Window menu integration for halves, quarters, fill, center, small and large layouts.
- Added bilingual action and window layout pickers. App, URL and shell actions remain supported.
- Window integration is experimental and awaits testing on the target iPad; requires a visible Window menu and an enabled window engine.

## 0.3.0

- Added a searchable installed-app picker.
- Launches or foregrounds apps through `com.conradkramer.open` from BigBoss.
- Retained URL and shell actions.
- Added English and Simplified Chinese interfaces that follow the system language.
- Added a complete iPhone/iPad icon set and a new original KeyPilot logo.
- Added arm64 and arm64e slices for rootless devices.
- Improved global rule distribution across sandboxed UIKit apps.
- Added per-keypress execution and debounce protection.

