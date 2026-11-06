// Local MacStatusBar&Dock integration, GPL-3.0-only with its host project.
// Include at the end of statusbar/StatusBar.x. ABI 1 uses plain C types.
// 0 = dispatched; 1 = wrong thread; 2 = unknown layout; 3 = no engine;
// 4 = no active app; 5 = app requires full screen; 6 = locked/busy.
__attribute__((visibility("default"), used))
int MSBDKeyPilotLayoutV1(const char *layout) {
    if (![NSThread isMainThread]) return 1;
    NSString *name = layout ? [NSString stringWithUTF8String:layout] : nil;
    if (![@[@"left", @"right", @"top", @"bottom", @"topleft", @"topright",
            @"bottomleft", @"bottomright", @"fill", @"center", @"small", @"large"] containsObject:name ?: @""]) return 2;
    id workspace = DMCall(objc_getClass("SBMainWorkspace"), @"sharedInstance");
    if (DMCoverSheetShown() || DMCall(workspace, @"currentTransaction")) return 6;
    if (DMActiveEngine() == DMEngineNone && !DMSMEngine()) return 3;
    SBApplication *app = DMActiveApp();
    NSString *bundle = [app bundleIdentifier];
    if (!bundle.length) return 4;
    if (DMAppNeedsFullScreen(bundle)) return 5;
    DMWindowLayout(name);
    return 0;
}

// Home must bypass the engine's "keep windows at Home" rewrite.
__attribute__((visibility("default"), used))
int MSBDKeyPilotHomeV1(void) {
    if (![NSThread isMainThread]) return 1;
    if (DMSMHomeUILocked()) return 6;
    for (DMNativeWindow *window in [gNativeWindows copy])
        if (!window.hidden && window.superview) [window minimize];
    if (DMSMEngine()) DMSMGoHomeForReal(@"KeyPilot Command+H");
    else { DMMinimizeAllWindows(); DMMinimize(); }
    return 0;
}

// Read-only confirmation: 1 Home, 2 App Switcher, 3 app, -1 unknown, -2 locked.
__attribute__((visibility("default"), used))
int MSBDKeyPilotHomeEnvironmentV1(void) {
    if (![NSThread isMainThread]) return -1;
    if (DMSMHomeUILocked()) return -2;
    long long environment = 0; id stage = nil;
    return DMSMHomeStateOf(DMSMHomeCurrentState(), &environment, &stage) ? (int)environment : -1;
}
