#import "KPWindowController.h"
#import "KPWindowActions.h"
#import <dlfcn.h>

BOOL KPPerformHomeAction(void (^completion)(BOOL, NSString *)) {
    NSCAssert(NSThread.isMainThread, @"Home actions require the main thread");
    void *handle = dlopen("/var/jb/usr/lib/MacStatusBarAndDock/MacStatusBarCore.dylib", RTLD_LAZY | RTLD_NOLOAD);
    int (*perform)(void) = (int (*)(void))dlsym(handle ?: RTLD_DEFAULT, "MSBDKeyPilotHomeV1");
    int (*environment)(void) = (int (*)(void))dlsym(handle ?: RTLD_DEFAULT, "MSBDKeyPilotHomeEnvironmentV1");
    if (!perform) { if (handle) dlclose(handle); return NO; }
    int result = perform();
    if (handle) dlclose(handle);
    if (result != 0) { completion(NO, @"Real Home refused (screen locked or wrong thread)"); return YES; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        int state = environment ? environment() : -1;
        completion(state == 1, [NSString stringWithFormat:@"Real Home environment=%d (1=Home, 2=Switcher, 3=App)", state]);
    });
    return YES;
}

void KPPerformWindowAction(NSString *input, void (^completion)(BOOL, NSString *)) {
    NSCAssert(NSThread.isMainThread, @"Window actions require the main thread");
    NSString *name = KPWindowActionName(input);
    if (!KPWindowActionTitles()[name]) { completion(NO, @"Unknown window layout"); return; }
    NSDictionary *names = @{@"left-half": @"left", @"right-half": @"right",
                            @"top-half": @"top", @"bottom-half": @"bottom",
                            @"top-left": @"topleft", @"top-right": @"topright",
                            @"bottom-left": @"bottomleft", @"bottom-right": @"bottomright"};
    NSString *layout = names[name] ?: name;
    typedef int (*LayoutFunction)(const char *);
    LayoutFunction perform = (LayoutFunction)dlsym(RTLD_DEFAULT, "MSBDKeyPilotLayoutV1");
    // NOLOAD: only query an already initialized payload, never load it ourselves.
    void *handle = NULL;
    if (!perform) {
        handle = dlopen("/var/jb/usr/lib/MacStatusBarAndDock/MacStatusBarCore.dylib", RTLD_LAZY | RTLD_NOLOAD);
        if (handle) perform = (LayoutFunction)dlsym(handle, "MSBDKeyPilotLayoutV1");
    }
    if (!perform) {
        if (handle) dlclose(handle);
        completion(NO, @"Direct layout bridge unavailable; install the KeyPilot-enabled MacStatusBarCore and respring");
        return;
    }
    int result = perform(layout.UTF8String);
    if (handle) dlclose(handle);
    NSArray *messages = @[@"Direct layout API dispatched", @"Wrong thread", @"Unknown layout",
                           @"Window engine is disabled", @"No active app window",
                           @"This app requires full screen", @"Screen locked or workspace transitioning"];
    completion(result == 0, result >= 0 && result < (int)messages.count ? messages[(NSUInteger)result] : @"Direct layout API returned an unknown status");
}
