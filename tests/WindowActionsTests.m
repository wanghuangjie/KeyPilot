#import <Foundation/Foundation.h>
#import "KPWindowActions.h"

int main(void) {
    @autoreleasepool {
        NSArray *expected = @[@"left-half", @"right-half", @"top-half", @"bottom-half",
                               @"top-left", @"top-right", @"bottom-left", @"bottom-right",
                               @"fill", @"center", @"small", @"large"];
        NSCAssert([KPWindowActionNames() isEqual:expected], @"All 12 layouts must be selectable");
        for (NSString *name in expected) {
            NSCAssert(KPWindowActionTitles()[name].length, @"Every layout requires an upstream menu label");
            NSCAssert([KPWindowActionName(name) isEqual:name], @"Canonical names must round-trip");
        }
        NSDictionary *cases = @{@" LEFT ": @"left-half", @"Right Half": @"right-half",
                                @"TOP_HALF": @"top-half", @"bottom": @"bottom-half",
                                @"maximize": @"fill", @"fill-screen": @"fill",
                                @"topleft": @"top-left", @"BottomRight": @"bottom-right"};
        for (NSString *input in cases) NSCAssert([KPWindowActionName(input) isEqual:cases[input]], @"Alias failed: %@", input);
        for (NSString *invalid in @[@"", @"quit", @"shell:reboot", @"left;reboot"])
            NSCAssert(!KPWindowActionTitles()[KPWindowActionName(invalid)], @"Invalid actions must not select a control");
        puts("Window action tests passed");
    }
    return 0;
}
