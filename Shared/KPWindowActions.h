#import <Foundation/Foundation.h>

// Stable KeyPilot action names; values are MacStatusBar&Dock's English menu labels.
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *KPWindowActionTitles(void);
FOUNDATION_EXPORT NSArray<NSString *> *KPWindowActionNames(void);
FOUNDATION_EXPORT NSString *KPWindowActionName(NSString *input);
