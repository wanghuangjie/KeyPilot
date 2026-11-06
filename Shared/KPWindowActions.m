#import "KPWindowActions.h"

NSDictionary<NSString *, NSString *> *KPWindowActionTitles(void) {
    return @{@"left-half": @"Left Half", @"right-half": @"Right Half",
             @"top-half": @"Top Half", @"bottom-half": @"Bottom Half",
             @"top-left": @"Top Left", @"top-right": @"Top Right",
             @"bottom-left": @"Bottom Left", @"bottom-right": @"Bottom Right",
             @"fill": @"Fill Screen", @"center": @"Center",
             @"small": @"Small", @"large": @"Large"};
}

NSArray<NSString *> *KPWindowActionNames(void) {
    return @[@"left-half", @"right-half", @"top-half", @"bottom-half",
             @"top-left", @"top-right", @"bottom-left", @"bottom-right",
             @"fill", @"center", @"small", @"large"];
}

NSString *KPWindowActionName(NSString *input) {
    NSString *name = [[input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    name = [[name stringByReplacingOccurrencesOfString:@"_" withString:@"-"] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    NSDictionary *aliases = @{@"left": @"left-half", @"right": @"right-half",
                              @"top": @"top-half", @"bottom": @"bottom-half",
                              @"maximize": @"fill", @"fill-screen": @"fill",
                              @"topleft": @"top-left", @"topright": @"top-right",
                              @"bottomleft": @"bottom-left", @"bottomright": @"bottom-right"};
    return aliases[name] ?: name;
}
