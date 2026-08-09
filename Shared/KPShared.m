#import "KPShared.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const KPPreferencesDomain = @"com.whj.keypilot";
NSString * const KPRulesKey = @"Rules";
NSString * const KPReloadNotification = @"com.whj.keypilot/reload";
NSString * const KPExecuteNotificationPrefix = @"com.whj.keypilot/execute/";
NSString * const KPRuleStateNotificationPrefix = @"com.whj.keypilot/rule-state/";
NSString * const KPRuleStatesReloadNotification = @"com.whj.keypilot/rule-states-reload";
NSString * const KPApplicationBundleIdentifier = @"com.whj.keypilot.app";
NSString * const KPLogPath = @"/var/mobile/Library/KeyPilot/keypilot.log";
NSUInteger const KPMaximumRuleCount = 64;

NSArray<NSDictionary *> *KPLoadRules(void) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)KPRulesKey,
                                                         (__bridge CFStringRef)KPPreferencesDomain);
    id object = CFBridgingRelease(value);
    if (![object isKindOfClass:[NSArray class]]) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *validRules = [NSMutableArray array];
    for (id candidate in (NSArray *)object) {
        if ([candidate isKindOfClass:[NSDictionary class]]) {
            [validRules addObject:[candidate copy]];
        }
        if (validRules.count >= KPMaximumRuleCount) {
            break;
        }
    }
    return validRules;
}

void KPSaveRules(NSArray<NSDictionary *> *rules) {
    NSArray *limited = rules.count > KPMaximumRuleCount
        ? [rules subarrayWithRange:NSMakeRange(0, KPMaximumRuleCount)]
        : rules;
    CFPreferencesSetAppValue((__bridge CFStringRef)KPRulesKey,
                             (__bridge CFPropertyListRef)limited,
                             (__bridge CFStringRef)KPPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)KPPreferencesDomain);
}

void KPPostReloadNotification(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)KPReloadNotification,
                                         NULL,
                                         NULL,
                                         true);
}

NSString *KPNormalizedKeyInput(NSString *input) {
    if (input.length == 0) {
        return @"";
    }
    if (input.length == 1) {
        return input.lowercaseString;
    }
    return input;
}

UIKeyModifierFlags KPRelevantModifierFlags(UIKeyModifierFlags flags) {
    UIKeyModifierFlags mask = UIKeyModifierAlphaShift |
                              UIKeyModifierShift |
                              UIKeyModifierControl |
                              UIKeyModifierAlternate |
                              UIKeyModifierCommand |
                              UIKeyModifierNumericPad;
    return flags & mask;
}

static NSString *KPKeyName(NSString *key) {
    NSDictionary<NSString *, NSString *> *names = @{
        UIKeyInputUpArrow: @"↑",
        UIKeyInputDownArrow: @"↓",
        UIKeyInputLeftArrow: @"←",
        UIKeyInputRightArrow: @"→",
        UIKeyInputEscape: NSLocalizedString(@"key.escape", nil),
        @"\r": NSLocalizedString(@"key.return", nil),
        @"\t": NSLocalizedString(@"key.tab", nil),
        @" ": NSLocalizedString(@"key.space", nil),
        @"\b": NSLocalizedString(@"key.delete", nil)
    };
    NSString *name = names[key];
    return name ?: key.uppercaseString;
}

NSString *KPShortcutDisplayString(NSString *key, UIKeyModifierFlags modifiers) {
    if (key.length == 0) {
        return NSLocalizedString(@"shortcut.record", nil);
    }
    NSMutableString *result = [NSMutableString string];
    if (modifiers & UIKeyModifierControl) [result appendString:@"⌃"];
    if (modifiers & UIKeyModifierAlternate) [result appendString:@"⌥"];
    if (modifiers & UIKeyModifierShift) [result appendString:@"⇧"];
    if (modifiers & UIKeyModifierCommand) [result appendString:@"⌘"];
    if (modifiers & UIKeyModifierAlphaShift) [result appendString:@"⇪"];
    [result appendString:KPKeyName(key)];
    return result;
}

NSString *KPExecuteNotificationName(NSUInteger index) {
    return [KPExecuteNotificationPrefix stringByAppendingFormat:@"%lu", (unsigned long)index];
}

NSString *KPRuleStateNotificationName(NSUInteger index) {
    return [KPRuleStateNotificationPrefix stringByAppendingFormat:@"%lu", (unsigned long)index];
}
