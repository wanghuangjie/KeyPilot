#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <spawn.h>
#import <sys/wait.h>
#import <fcntl.h>
#import <notify.h>
#import "KPShared.h"
#import "KPWindowController.h"

extern char **environ;

static NSArray<NSDictionary *> *KPRules = nil;
static BOOL KPIsSpringBoard = NO;
static uint64_t KPRuleStates[64] = {0};
static int KPRuleStateTokens[64] = {0};
static BOOL KPRuleStateTokenValid[64] = {NO};
static NSTimeInterval KPLastExecutionTimes[64] = {0};

static uint8_t KPCompactModifiers(UIKeyModifierFlags modifiers) {
    uint8_t compact = 0;
    if (modifiers & UIKeyModifierAlphaShift) compact |= 1 << 0;
    if (modifiers & UIKeyModifierShift) compact |= 1 << 1;
    if (modifiers & UIKeyModifierControl) compact |= 1 << 2;
    if (modifiers & UIKeyModifierAlternate) compact |= 1 << 3;
    if (modifiers & UIKeyModifierCommand) compact |= 1 << 4;
    if (modifiers & UIKeyModifierNumericPad) compact |= 1 << 5;
    return compact;
}

static UIKeyboardHIDUsage KPFallbackKeyCodeForString(NSString *key) {
    NSString *normalized = KPNormalizedKeyInput(key ?: @"");
    if (normalized.length == 1) {
        unichar character = [normalized characterAtIndex:0];
        if (character >= 'a' && character <= 'z') {
            return (UIKeyboardHIDUsage)(UIKeyboardHIDUsageKeyboardA + character - 'a');
        }
        if (character >= '1' && character <= '9') {
            return (UIKeyboardHIDUsage)(UIKeyboardHIDUsageKeyboard1 + character - '1');
        }
        if (character == '0') return UIKeyboardHIDUsageKeyboard0;
        if (character == '\r') return UIKeyboardHIDUsageKeyboardReturnOrEnter;
        if (character == '\t') return UIKeyboardHIDUsageKeyboardTab;
        if (character == ' ') return UIKeyboardHIDUsageKeyboardSpacebar;
        if (character == '\b') return UIKeyboardHIDUsageKeyboardDeleteOrBackspace;
    }
    if ([normalized isEqualToString:UIKeyInputEscape]) return UIKeyboardHIDUsageKeyboardEscape;
    if ([normalized isEqualToString:UIKeyInputUpArrow]) return UIKeyboardHIDUsageKeyboardUpArrow;
    if ([normalized isEqualToString:UIKeyInputDownArrow]) return UIKeyboardHIDUsageKeyboardDownArrow;
    if ([normalized isEqualToString:UIKeyInputLeftArrow]) return UIKeyboardHIDUsageKeyboardLeftArrow;
    if ([normalized isEqualToString:UIKeyInputRightArrow]) return UIKeyboardHIDUsageKeyboardRightArrow;
    return 0;
}

static uint64_t KPEncodedRuleState(NSDictionary *rule) {
    UIKeyboardHIDUsage keyCode = [rule[@"keyCode"] unsignedIntegerValue];
    if (keyCode == 0) {
        keyCode = KPFallbackKeyCodeForString([rule[@"key"] isKindOfClass:[NSString class]] ? rule[@"key"] : @"");
    }
    NSString *action = [rule[@"action"] isKindOfClass:[NSString class]] ? rule[@"action"] : @"";
    BOOL active = [rule[@"enabled"] boolValue] && keyCode != 0 && action.length != 0;
    BOOL consume = ![rule[@"passthrough"] boolValue];
    uint8_t modifiers = KPCompactModifiers([rule[@"modifiers"] unsignedIntegerValue]);
    return ((uint64_t)keyCode & 0xffffULL) |
           ((uint64_t)modifiers << 16) |
           ((uint64_t)active << 24) |
           ((uint64_t)consume << 25);
}

static void KPRegisterRuleStateTokens(void) {
    for (NSUInteger index = 0; index < KPMaximumRuleCount; index++) {
        int token = 0;
        uint32_t status = notify_register_check(KPRuleStateNotificationName(index).UTF8String, &token);
        if (status == NOTIFY_STATUS_OK) {
            KPRuleStateTokens[index] = token;
            KPRuleStateTokenValid[index] = YES;
        }
    }
}

static void KPLoadExportedRuleStates(void) {
    for (NSUInteger index = 0; index < KPMaximumRuleCount; index++) {
        uint64_t state = 0;
        if (KPRuleStateTokenValid[index]) {
            notify_get_state(KPRuleStateTokens[index], &state);
        }
        KPRuleStates[index] = state;
    }
}

static NSUInteger KPActiveExportedRuleCount(void) {
    NSUInteger count = 0;
    for (NSUInteger index = 0; index < KPMaximumRuleCount; index++) {
        if ((KPRuleStates[index] & (1ULL << 24)) != 0) count++;
    }
    return count;
}

static void KPExportRuleStates(void) {
    for (NSUInteger index = 0; index < KPMaximumRuleCount; index++) {
        uint64_t state = index < KPRules.count ? KPEncodedRuleState(KPRules[index]) : 0;
        KPRuleStates[index] = state;
        if (KPRuleStateTokenValid[index]) {
            notify_set_state(KPRuleStateTokens[index], state);
        }
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)KPRuleStatesReloadNotification,
                                         NULL,
                                         NULL,
                                         true);
}

static void KPLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

static void KPLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);

    NSString *folder = [KPLogPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder
                              withIntermediateDirectories:YES
                                               attributes:@{NSFilePosixPermissions: @0755}
                                                    error:nil];
    if (![[NSFileManager defaultManager] fileExistsAtPath:KPLogPath]) {
        [[NSData data] writeToFile:KPLogPath atomically:YES];
        [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0644}
                                        ofItemAtPath:KPLogPath
                                               error:nil];
    }

    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:KPLogPath];
    @try {
        [handle seekToEndOfFile];
        [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    } @catch (__unused NSException *exception) {
    }
}

static void KPReloadRules(void) {
    KPRules = KPLoadRules();
    if (KPIsSpringBoard) {
        KPExportRuleStates();
    }
}

static void KPReloadCallback(CFNotificationCenterRef center,
                             void *observer,
                             CFStringRef name,
                             const void *object,
                             CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (KPIsSpringBoard) {
            KPReloadRules();
        }
    });
}

static void KPRuleStatesReloadCallback(CFNotificationCenterRef center,
                                       void *observer,
                                       CFStringRef name,
                                       const void *object,
                                       CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        KPLoadExportedRuleStates();
    });
}

static NSString *KPTrimmedValueAfterPrefix(NSString *action, NSString *prefix) {
    NSString *value = [action substringFromIndex:prefix.length];
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static void KPOpenApplicationViaLaunchServices(NSString *bundleIdentifier) {
    if (bundleIdentifier.length == 0) return;

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) {
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
        dlopen("/System/Library/PrivateFrameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
        workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    }
    SEL sharedSelector = NSSelectorFromString(@"defaultWorkspace");
    SEL openSelector = NSSelectorFromString(@"openApplicationWithBundleID:");
    if (![workspaceClass respondsToSelector:sharedSelector]) {
        KPLog(@"Unable to obtain LSApplicationWorkspace");
        return;
    }

    id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    BOOL (*sendBoolObject)(id, SEL, id) = (BOOL (*)(id, SEL, id))objc_msgSend;
    id workspace = sendObject(workspaceClass, sharedSelector);
    if (![workspace respondsToSelector:openSelector]) {
        KPLog(@"openApplicationWithBundleID: is unavailable on this system");
        return;
    }

    BOOL opened = sendBoolObject(workspace, openSelector, bundleIdentifier);
    KPLog(@"LaunchServices opened %@: %@", bundleIdentifier, opened ? @"success" : @"failed");
}

static NSString *KPOpenToolPath(void) {
    for (NSString *candidate in @[@"/var/jb/usr/bin/open", @"/var/jb/bin/open", @"/usr/bin/open"]) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:candidate]) {
            return candidate;
        }
    }
    return nil;
}

static void KPOpenApplication(NSString *bundleIdentifier) {
    NSString *identifier = [bundleIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (identifier.length == 0) return;

    NSString *toolPath = KPOpenToolPath();
    if (!toolPath) {
        KPLog(@"com.conradkramer.open was not found; falling back to LaunchServices for %@", identifier);
        KPOpenApplicationViaLaunchServices(identifier);
        return;
    }

    KPLog(@"Invoking %@ %@", toolPath, identifier);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        const char *argv[] = {
            toolPath.fileSystemRepresentation,
            identifier.UTF8String,
            NULL
        };

        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_addopen(&actions,
                                         STDOUT_FILENO,
                                         KPLogPath.fileSystemRepresentation,
                                         O_WRONLY | O_CREAT | O_APPEND,
                                         0644);
        posix_spawn_file_actions_adddup2(&actions, STDOUT_FILENO, STDERR_FILENO);

        NSString *path = @"PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        NSString *home = @"HOME=/var/mobile";
        NSString *user = @"USER=mobile";
        char *environment[] = {
            (char *)path.UTF8String,
            (char *)home.UTF8String,
            (char *)user.UTF8String,
            NULL
        };

        pid_t pid = 0;
        int result = posix_spawn(&pid,
                                 toolPath.fileSystemRepresentation,
                                 &actions,
                                 NULL,
                                 (char * const *)argv,
                                 environment);
        posix_spawn_file_actions_destroy(&actions);
        if (result != 0) {
            KPLog(@"open failed to launch (%d); falling back to LaunchServices for %@", result, identifier);
            dispatch_async(dispatch_get_main_queue(), ^{
                KPOpenApplicationViaLaunchServices(identifier);
            });
            return;
        }

        int status = 0;
        waitpid(pid, &status, 0);
        KPLog(@"open pid=%d exited with status=%d, target=%@", pid, status, identifier);
    });
}

static void KPOpenURLString(NSString *URLString) {
    NSURL *URL = [NSURL URLWithString:URLString];
    if (!URL) {
        KPLog(@"Invalid URL: %@", URLString);
        return;
    }
    [[UIApplication sharedApplication] openURL:URL
                                       options:@{}
                             completionHandler:^(BOOL success) {
        KPLog(@"Opened URL %@: %@", URLString, success ? @"success" : @"failed");
    }];
}

static NSString *KPShellPath(void) {
    for (NSString *candidate in @[@"/var/jb/bin/sh", @"/var/jb/usr/bin/sh", @"/bin/sh"]) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:candidate]) {
            return candidate;
        }
    }
    return @"/bin/sh";
}

static void KPRunShellCommand(NSString *command) {
    if (command.length == 0) return;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *shell = KPShellPath();
        const char *argv[] = {
            shell.fileSystemRepresentation,
            "-c",
            command.UTF8String,
            NULL
        };

        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_addopen(&actions,
                                         STDOUT_FILENO,
                                         KPLogPath.fileSystemRepresentation,
                                         O_WRONLY | O_CREAT | O_APPEND,
                                         0644);
        posix_spawn_file_actions_adddup2(&actions, STDOUT_FILENO, STDERR_FILENO);

        NSString *path = @"PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        NSString *home = @"HOME=/var/mobile";
        NSString *user = @"USER=mobile";
        char *environment[] = {
            (char *)path.UTF8String,
            (char *)home.UTF8String,
            (char *)user.UTF8String,
            NULL
        };

        pid_t pid = 0;
        int result = posix_spawn(&pid,
                                 shell.fileSystemRepresentation,
                                 &actions,
                                 NULL,
                                 (char * const *)argv,
                                 environment);
        posix_spawn_file_actions_destroy(&actions);

        if (result != 0) {
            KPLog(@"Command failed to launch (%d): %@", result, command);
            return;
        }

        KPLog(@"Command pid=%d: %@", pid, command);
        int status = 0;
        waitpid(pid, &status, 0);
        KPLog(@"Command pid=%d exited with status=%d", pid, status);
    });
}

static void KPReturnHome(void) {
    if (KPPerformHomeAction(^(BOOL success, NSString *message) {
        KPLog(@"Home action %@: %@", success ? @"verified" : @"not verified", message);
    })) return;
    UIApplication *app = UIApplication.sharedApplication;
    for (NSString *name in @[@"_simulateHomeButtonPress", @"_simulateHomeButtonPressWithCompletion:"]) {
        SEL selector = NSSelectorFromString(name);
        if (![app respondsToSelector:selector]) continue;
        if ([name hasSuffix:@":"]) ((void (*)(id, SEL, id))objc_msgSend)(app, selector, nil);
        else ((void (*)(id, SEL))objc_msgSend)(app, selector);
        KPLog(@"Home action dispatched via %@", name);
        return;
    }
    KPLog(@"Home action unavailable: no supported SpringBoard selector");
}

static void KPSeedHomeShortcut(void) {
    CFStringRef domain = (__bridge CFStringRef)KPPreferencesDomain;
    if (CFPreferencesGetAppBooleanValue(CFSTR("HomeShortcutSeeded"), domain, NULL)) return;
    NSMutableArray *rules = [KPLoadRules() mutableCopy];
    NSUInteger found = NSNotFound;
    for (NSUInteger i = 0; i < rules.count; i++) {
        NSDictionary *r = rules[i];
        if ([r[@"modifiers"] unsignedIntegerValue] == UIKeyModifierCommand &&
            ([r[@"keyCode"] unsignedIntegerValue] == UIKeyboardHIDUsageKeyboardH ||
             [KPNormalizedKeyInput(r[@"key"] ?: @"") isEqualToString:@"h"])) { found = i; break; }
    }
    NSDictionary *home = @{@"key": @"h", @"keyCode": @(UIKeyboardHIDUsageKeyboardH),
                            @"modifiers": @(UIKeyModifierCommand), @"action": @"system:home",
                            @"enabled": @YES, @"passthrough": @NO};
    if (found != NSNotFound) rules[found] = home;
    else if (rules.count < KPMaximumRuleCount) [rules addObject:home];
    else { KPLog(@"Cannot add Command+H: rule limit reached"); return; }
    KPSaveRules(rules);
    CFPreferencesSetAppValue(CFSTR("HomeShortcutSeeded"), kCFBooleanTrue, domain);
    CFPreferencesAppSynchronize(domain);
    KPLog(@"Command+H Home shortcut installed");
}

static void KPExecuteAction(NSString *rawAction) {
    NSString *action = [rawAction stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (action.length == 0) return;

    NSString *lowercase = action.lowercaseString;
    if ([lowercase isEqualToString:@"system:home"]) {
        KPReturnHome();
    } else if ([lowercase hasPrefix:@"window:"]) {
        KPPerformWindowAction(KPTrimmedValueAfterPrefix(action, @"window:"), ^(BOOL success, NSString *message) {
            KPLog(@"Window action %@: %@ (%@)", action, success ? @"dispatched" : @"failed", message);
        });
    } else if ([lowercase hasPrefix:@"app:"]) {
        KPOpenApplication(KPTrimmedValueAfterPrefix(action, @"app:"));
    } else if ([lowercase hasPrefix:@"open:"]) {
        KPOpenApplication(KPTrimmedValueAfterPrefix(action, @"open:"));
    } else if ([lowercase hasPrefix:@"url:"]) {
        KPOpenURLString(KPTrimmedValueAfterPrefix(action, @"url:"));
    } else if ([lowercase hasPrefix:@"shell:"]) {
        KPRunShellCommand(KPTrimmedValueAfterPrefix(action, @"shell:"));
    } else if ([lowercase hasPrefix:@"sh:"]) {
        KPRunShellCommand(KPTrimmedValueAfterPrefix(action, @"sh:"));
    } else {
        KPOpenApplication(action);
    }
}

static void KPExecuteCallback(CFNotificationCenterRef center,
                              void *observer,
                              CFStringRef name,
                              const void *object,
                              CFDictionaryRef userInfo) {
    NSString *notificationName = (__bridge NSString *)name;
    NSString *suffix = [notificationName substringFromIndex:KPExecuteNotificationPrefix.length];
    NSInteger index = suffix.integerValue;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<NSDictionary *> *latestRules = KPLoadRules();
        if (index < 0 || (NSUInteger)index >= latestRules.count) return;
        NSDictionary *rule = latestRules[(NSUInteger)index];
        if (![rule[@"enabled"] boolValue]) return;

        NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
        if (now - KPLastExecutionTimes[(NSUInteger)index] < 0.45) return;
        KPLastExecutionTimes[(NSUInteger)index] = now;
        KPExecuteAction([rule[@"action"] isKindOfClass:[NSString class]] ? rule[@"action"] : @"");
    });
}

static BOOL KPHandlePressesEvent(UIPressesEvent *event) {
    for (UIPress *press in event.allPresses) {
        if (press.phase != UIPressPhaseBegan || !press.key) continue;

        NSString *input = KPNormalizedKeyInput(press.key.charactersIgnoringModifiers ?: @"");
        UIKeyModifierFlags modifiers = KPRelevantModifierFlags(press.key.modifierFlags);
        UIKeyboardHIDUsage keyCode = press.key.keyCode;
        uint8_t compactModifiers = KPCompactModifiers(modifiers);
        if (keyCode == 0) continue;

        for (NSUInteger index = 0; index < KPMaximumRuleCount; index++) {
            uint64_t state = KPRuleStates[index];
            BOOL active = (state & (1ULL << 24)) != 0;
            BOOL consume = (state & (1ULL << 25)) != 0;
            UIKeyboardHIDUsage ruleKeyCode = (UIKeyboardHIDUsage)(state & 0xffffULL);
            uint8_t ruleModifiers = (uint8_t)((state >> 16) & 0xffULL);
            if (!active) continue;

            if (ruleKeyCode == keyCode && ruleModifiers == compactModifiers) {
                NSLog(@"[KeyPilot] %@ matched rule %lu in %@",
                      KPShortcutDisplayString(input, modifiers),
                      (unsigned long)index,
                      NSProcessInfo.processInfo.processName);
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                     (__bridge CFStringRef)KPExecuteNotificationName(index),
                                                     NULL,
                                                     NULL,
                                                     true);
                return consume;
            }
        }
    }
    return NO;
}

%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    if (![bundleIdentifier isEqualToString:KPApplicationBundleIdentifier] &&
        [event isKindOfClass:NSClassFromString(@"UIPressesEvent")] &&
        KPHandlePressesEvent((UIPressesEvent *)event)) {
        return;
    }
    %orig;
}

%end

%ctor {
    @autoreleasepool {
        NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier ?: @"";
        KPIsSpringBoard = [bundleIdentifier isEqualToString:@"com.apple.springboard"] ||
                          [NSProcessInfo.processInfo.processName isEqualToString:@"SpringBoard"];
        KPRegisterRuleStateTokens();
        if (KPIsSpringBoard) {
            KPSeedHomeShortcut();
            KPReloadRules();
        } else {
            KPLoadExportedRuleStates();
        }
        NSLog(@"[KeyPilot] Loaded in %@; active rule count=%lu",
              NSProcessInfo.processInfo.processName,
              (unsigned long)KPActiveExportedRuleCount());

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        KPReloadCallback,
                                        (__bridge CFStringRef)KPReloadNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        KPRuleStatesReloadCallback,
                                        (__bridge CFStringRef)KPRuleStatesReloadNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        if (KPIsSpringBoard) {
            for (NSUInteger index = 0; index < KPMaximumRuleCount; index++) {
                CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                                NULL,
                                                KPExecuteCallback,
                                                (__bridge CFStringRef)KPExecuteNotificationName(index),
                                                NULL,
                                                CFNotificationSuspensionBehaviorDeliverImmediately);
            }
            KPLog(@"KeyPilot loaded in SpringBoard");
        }
    }
}
