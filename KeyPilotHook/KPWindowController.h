#import <Foundation/Foundation.h>

// Must be called on SpringBoard's main thread. Completion reports dispatch, not geometry.
FOUNDATION_EXPORT void KPPerformWindowAction(NSString *name, void (^completion)(BOOL success, NSString *message));
FOUNDATION_EXPORT BOOL KPPerformHomeAction(void (^completion)(BOOL success, NSString *message));
