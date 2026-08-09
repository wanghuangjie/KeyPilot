#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const KPPreferencesDomain;
FOUNDATION_EXPORT NSString * const KPRulesKey;
FOUNDATION_EXPORT NSString * const KPReloadNotification;
FOUNDATION_EXPORT NSString * const KPExecuteNotificationPrefix;
FOUNDATION_EXPORT NSString * const KPRuleStateNotificationPrefix;
FOUNDATION_EXPORT NSString * const KPRuleStatesReloadNotification;
FOUNDATION_EXPORT NSString * const KPApplicationBundleIdentifier;
FOUNDATION_EXPORT NSString * const KPLogPath;
FOUNDATION_EXPORT NSUInteger const KPMaximumRuleCount;

FOUNDATION_EXPORT NSArray<NSDictionary *> *KPLoadRules(void);
FOUNDATION_EXPORT void KPSaveRules(NSArray<NSDictionary *> *rules);
FOUNDATION_EXPORT void KPPostReloadNotification(void);
FOUNDATION_EXPORT NSString *KPNormalizedKeyInput(NSString *input);
FOUNDATION_EXPORT UIKeyModifierFlags KPRelevantModifierFlags(UIKeyModifierFlags flags);
FOUNDATION_EXPORT NSString *KPShortcutDisplayString(NSString *key, UIKeyModifierFlags modifiers);
FOUNDATION_EXPORT NSString *KPExecuteNotificationName(NSUInteger index);
FOUNDATION_EXPORT NSString *KPRuleStateNotificationName(NSUInteger index);

NS_ASSUME_NONNULL_END
