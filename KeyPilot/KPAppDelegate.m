#import "KPAppDelegate.h"
#import "KPShared.h"
#import "KPWindowActions.h"
#import <objc/message.h>
#import <dlfcn.h>

typedef void (^KPShortcutCaptureHandler)(NSString *key,
                                         UIKeyModifierFlags modifiers,
                                         UIKeyboardHIDUsage keyCode);
typedef void (^KPAppSelectionHandler)(NSString *bundleIdentifier, NSString *displayName);

@interface KPShortcutCaptureController : UIViewController
@property (nonatomic, copy) KPShortcutCaptureHandler captureHandler;
@property (nonatomic, strong) UILabel *shortcutLabel;
@end

@interface KPActionCell : UITableViewCell
@property (nonatomic, strong) UIButton *shortcutButton;
@property (nonatomic, strong) UITextField *actionField;
@property (nonatomic, strong) UIButton *appPickerButton;
@property (nonatomic, strong) UISwitch *enabledSwitch;
@end

@interface KPAppPickerController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, copy) KPAppSelectionHandler selectionHandler;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *> *allApps;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *> *visibleApps;
@end

@interface KPLogController : UIViewController
@end


@implementation KPAppPickerController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"app_picker.title", nil);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                           target:self
                                                                                           action:@selector(cancel)];
    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    search.searchBar.placeholder = NSLocalizedString(@"app_picker.search", nil);
    self.navigationItem.searchController = search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    [self loadInstalledApps];
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadInstalledApps {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) {
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
        dlopen("/System/Library/PrivateFrameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
        workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    }

    id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id workspace = [workspaceClass respondsToSelector:NSSelectorFromString(@"defaultWorkspace")]
        ? sendObject(workspaceClass, NSSelectorFromString(@"defaultWorkspace"))
        : nil;
    NSArray *proxies = [workspace respondsToSelector:NSSelectorFromString(@"allInstalledApplications")]
        ? sendObject(workspace, NSSelectorFromString(@"allInstalledApplications"))
        : @[];

    NSMutableDictionary<NSString *, NSDictionary *> *uniqueApps = [NSMutableDictionary dictionary];
    for (id proxy in proxies) {
        NSString *bundleIdentifier = [proxy respondsToSelector:NSSelectorFromString(@"bundleIdentifier")]
            ? sendObject(proxy, NSSelectorFromString(@"bundleIdentifier"))
            : nil;
        NSString *name = [proxy respondsToSelector:NSSelectorFromString(@"localizedName")]
            ? sendObject(proxy, NSSelectorFromString(@"localizedName"))
            : nil;
        if (bundleIdentifier.length == 0) continue;
        uniqueApps[bundleIdentifier] = @{
            @"bundleIdentifier": bundleIdentifier,
            @"name": name.length ? name : bundleIdentifier
        };
    }

    self.allApps = [[uniqueApps allValues] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"name"] localizedStandardCompare:right[@"name"]];
    }];
    self.visibleApps = self.allApps;
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (query.length == 0) {
        self.visibleApps = self.allApps;
    } else {
        self.visibleApps = [self.allApps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *app, NSDictionary *bindings) {
            return [app[@"name"] localizedCaseInsensitiveContainsString:query] ||
                   [app[@"bundleIdentifier"] localizedCaseInsensitiveContainsString:query];
        }]];
    }
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"InstalledApp";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSDictionary *app = self.visibleApps[(NSUInteger)indexPath.row];
    cell.textLabel.text = app[@"name"];
    cell.detailTextLabel.text = app[@"bundleIdentifier"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *app = self.visibleApps[(NSUInteger)indexPath.row];
    KPAppSelectionHandler handler = self.selectionHandler;
    [self dismissViewControllerAnimated:YES completion:^{
        if (handler) handler(app[@"bundleIdentifier"], app[@"name"]);
    }];
}

@end

@interface KPRulesController : UITableViewController <UITextFieldDelegate>
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *rules;
@end

@implementation KPShortcutCaptureController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = NSLocalizedString(@"capture.title", nil);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                           target:self
                                                                                           action:@selector(cancel)];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = NSLocalizedString(@"capture.instruction", nil);
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    title.textAlignment = NSTextAlignmentCenter;

    self.shortcutLabel = [[UILabel alloc] init];
    self.shortcutLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.shortcutLabel.text = NSLocalizedString(@"capture.waiting", nil);
    self.shortcutLabel.font = [UIFont monospacedSystemFontOfSize:34 weight:UIFontWeightSemibold];
    self.shortcutLabel.textColor = UIColor.systemBlueColor;
    self.shortcutLabel.textAlignment = NSTextAlignmentCenter;

    UILabel *hint = [[UILabel alloc] init];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.text = NSLocalizedString(@"capture.hint", nil);
    hint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    hint.textColor = UIColor.secondaryLabelColor;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 0;

    [self.view addSubview:title];
    [self.view addSubview:self.shortcutLabel];
    [self.view addSubview:hint];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:36],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.shortcutLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:30],
        [self.shortcutLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.shortcutLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [hint.topAnchor constraintEqualToAnchor:self.shortcutLabel.bottomAnchor constant:30],
        [hint.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [hint.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30]
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for (UIPress *press in presses) {
        UIKey *keyObject = press.key;
        if (!keyObject) continue;
        NSString *key = KPNormalizedKeyInput(keyObject.charactersIgnoringModifiers ?: @"");
        UIKeyModifierFlags modifiers = KPRelevantModifierFlags(keyObject.modifierFlags);
        if (key.length == 0) continue;

        self.shortcutLabel.text = KPShortcutDisplayString(key, modifiers);
        KPShortcutCaptureHandler handler = self.captureHandler;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:^{
                if (handler) handler(key, modifiers, keyObject.keyCode);
            }];
        });
        return;
    }
    [super pressesBegan:presses withEvent:event];
}

@end

@implementation KPActionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;

    self.shortcutButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.shortcutButton.titleLabel.font = [UIFont monospacedSystemFontOfSize:17 weight:UIFontWeightSemibold];
    self.shortcutButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;

    self.actionField = [[UITextField alloc] init];
    self.actionField.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    self.actionField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.actionField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.actionField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.actionField.placeholder = NSLocalizedString(@"action.placeholder", nil);
    self.actionField.returnKeyType = UIReturnKeyDone;

    self.appPickerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.appPickerButton setImage:[UIImage systemImageNamed:@"list.bullet"] forState:UIControlStateNormal];
    self.appPickerButton.accessibilityLabel = NSLocalizedString(@"action.choose", nil);

    self.enabledSwitch = [[UISwitch alloc] init];

    for (UIView *view in @[self.shortcutButton, self.actionField, self.appPickerButton, self.enabledSwitch]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:view];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.shortcutButton.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
        [self.shortcutButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.shortcutButton.widthAnchor constraintEqualToConstant:145],
        [self.actionField.leadingAnchor constraintEqualToAnchor:self.shortcutButton.trailingAnchor constant:8],
        [self.actionField.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.appPickerButton.leadingAnchor constraintEqualToAnchor:self.actionField.trailingAnchor constant:6],
        [self.appPickerButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.appPickerButton.widthAnchor constraintEqualToConstant:34],
        [self.enabledSwitch.leadingAnchor constraintEqualToAnchor:self.appPickerButton.trailingAnchor constant:6],
        [self.enabledSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
        [self.enabledSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor]
    ]];
    return self;
}

@end

@implementation KPLogController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"log.title", nil);
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.editable = NO;
    textView.alwaysBounceVertical = YES;
    textView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    NSError *error = nil;
    NSString *contents = [NSString stringWithContentsOfFile:KPLogPath encoding:NSUTF8StringEncoding error:&error];
    textView.text = contents.length ? contents : NSLocalizedString(@"log.empty", nil);
    [self.view addSubview:textView];
    [NSLayoutConstraint activateConstraints:@[
        [textView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8]
    ]];
}

@end

@implementation KPRulesController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"KeyPilot";
    self.tableView.rowHeight = 64;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.tableView registerClass:[KPActionCell class] forCellReuseIdentifier:@"Action"];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                            target:self
                                                                                            action:@selector(addRule)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"rules.help", nil)
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(showHelp)];
    self.toolbarItems = @[
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"log.title", nil) style:UIBarButtonItemStylePlain target:self action:@selector(showLog)],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"rules.live_update", nil) style:UIBarButtonItemStylePlain target:nil action:nil]
    ];
    [self.navigationController setToolbarHidden:NO animated:NO];

    self.rules = [NSMutableArray array];
    for (NSDictionary *storedRule in KPLoadRules()) {
        NSMutableDictionary *rule = [storedRule mutableCopy];
        if (!rule[@"enabled"]) rule[@"enabled"] = @YES;
        if (!rule[@"passthrough"]) rule[@"passthrough"] = @NO;
        [self.rules addObject:rule];
    }
    if (self.rules.count == 0) {
        [self.rules addObject:[self emptyRule]];
    }
}

- (NSMutableDictionary *)emptyRule {
    return [@{
        @"key": @"",
        @"modifiers": @0,
        @"action": @"",
        @"enabled": @YES,
        @"passthrough": @NO
    } mutableCopy];
}

- (void)saveRules {
    KPSaveRules(self.rules);
    KPPostReloadNotification();
}

- (void)addRule {
    if (self.rules.count >= KPMaximumRuleCount) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"limit.title", nil)
                                                                       message:NSLocalizedString(@"limit.message", nil)
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"common.ok", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self.rules addObject:[self emptyRule]];
    NSIndexPath *path = [NSIndexPath indexPathForRow:self.rules.count - 1 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self saveRules];
}

- (void)showHelp {
    NSString *message = NSLocalizedString(@"help.message", nil);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"help.title", nil)
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"common.got_it", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLog {
    [self.navigationController pushViewController:[[KPLogController alloc] init] animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rules.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(@"rules.header", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return NSLocalizedString(@"rules.footer", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KPActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Action" forIndexPath:indexPath];
    NSDictionary *rule = self.rules[(NSUInteger)indexPath.row];
    NSString *key = [rule[@"key"] isKindOfClass:[NSString class]] ? rule[@"key"] : @"";
    UIKeyModifierFlags modifiers = [rule[@"modifiers"] unsignedIntegerValue];
    [cell.shortcutButton setTitle:KPShortcutDisplayString(key, modifiers) forState:UIControlStateNormal];
    cell.shortcutButton.tag = indexPath.row;
    [cell.shortcutButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.shortcutButton addTarget:self action:@selector(captureShortcut:) forControlEvents:UIControlEventTouchUpInside];

    cell.actionField.text = [rule[@"action"] isKindOfClass:[NSString class]] ? rule[@"action"] : @"";
    cell.actionField.tag = indexPath.row;
    cell.actionField.delegate = self;
    [cell.actionField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    [cell.actionField addTarget:self action:@selector(actionChanged:) forControlEvents:UIControlEventEditingChanged];

    cell.appPickerButton.tag = indexPath.row;
    [cell.appPickerButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.appPickerButton addTarget:self action:@selector(selectApp:) forControlEvents:UIControlEventTouchUpInside];

    cell.enabledSwitch.on = [rule[@"enabled"] boolValue];
    cell.enabledSwitch.tag = indexPath.row;
    [cell.enabledSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    [cell.enabledSwitch addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
    return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)actionChanged:(UITextField *)field {
    NSUInteger index = (NSUInteger)field.tag;
    if (index >= self.rules.count) return;
    self.rules[index][@"action"] = field.text ?: @"";
    [self saveRules];
}

- (void)enabledChanged:(UISwitch *)sender {
    NSUInteger index = (NSUInteger)sender.tag;
    if (index >= self.rules.count) return;
    self.rules[index][@"enabled"] = @(sender.on);
    [self saveRules];
}

- (void)selectApp:(UIButton *)sender {
    NSUInteger index = (NSUInteger)sender.tag;
    if (index >= self.rules.count) return;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"action.choose", nil)
                                                                 message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app_picker.title", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showAppPicker:sender];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"window.choose", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showWindowPicker:sender];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"system.home", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if (index >= self.rules.count) return;
        self.rules[index][@"action"] = @"system:home";
        [self saveRules];
        [self.tableView reloadData];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"common.cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.sourceView = sender;
    menu.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)showWindowPicker:(UIButton *)sender {
    NSUInteger index = (NSUInteger)sender.tag;
    if (index >= self.rules.count) return;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"window.choose", nil)
                                                                 message:NSLocalizedString(@"window.requirement", nil)
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *name in KPWindowActionNames()) {
        NSString *key = [@"window." stringByAppendingString:name];
        [menu addAction:[UIAlertAction actionWithTitle:NSLocalizedString(key, nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (index >= self.rules.count) return;
            self.rules[index][@"action"] = [@"window:" stringByAppendingString:name];
            [self saveRules];
            [self.tableView reloadData];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"common.cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.sourceView = sender;
    menu.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)showAppPicker:(UIButton *)sender {
    NSUInteger index = (NSUInteger)sender.tag;
    if (index >= self.rules.count) return;

    KPAppPickerController *picker = [[KPAppPickerController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    __weak typeof(self) weakSelf = self;
    picker.selectionHandler = ^(NSString *bundleIdentifier, NSString *displayName) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || index >= self.rules.count) return;
        self.rules[index][@"action"] = [@"app:" stringByAppendingString:bundleIdentifier];
        [self saveRules];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:(NSInteger)index inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
    };
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    navigation.preferredContentSize = CGSizeMake(620, 720);
    [self presentViewController:navigation animated:YES completion:nil];
}

- (BOOL)shortcutKey:(NSString *)key modifiers:(UIKeyModifierFlags)modifiers duplicatesIndex:(NSUInteger)targetIndex {
    for (NSUInteger index = 0; index < self.rules.count; index++) {
        if (index == targetIndex) continue;
        NSDictionary *rule = self.rules[index];
        if ([KPNormalizedKeyInput(rule[@"key"] ?: @"") isEqualToString:key] &&
            [rule[@"modifiers"] unsignedIntegerValue] == modifiers) {
            return YES;
        }
    }
    return NO;
}

- (void)captureShortcut:(UIButton *)sender {
    NSUInteger index = (NSUInteger)sender.tag;
    if (index >= self.rules.count) return;

    KPShortcutCaptureController *capture = [[KPShortcutCaptureController alloc] init];
    __weak typeof(self) weakSelf = self;
    capture.captureHandler = ^(NSString *key,
                               UIKeyModifierFlags modifiers,
                               UIKeyboardHIDUsage keyCode) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || index >= self.rules.count) return;
        if ([self shortcutKey:key modifiers:modifiers duplicatesIndex:index]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"duplicate.title", nil)
                                                                           message:NSLocalizedString(@"duplicate.message", nil)
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"common.ok", nil) style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        self.rules[index][@"key"] = key;
        self.rules[index][@"modifiers"] = @(modifiers);
        self.rules[index][@"keyCode"] = @(keyCode);
        [self saveRules];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:(NSInteger)index inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
    };

    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:capture];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    navigation.preferredContentSize = CGSizeMake(520, 300);
    [self presentViewController:navigation animated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
 forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    [self.rules removeObjectAtIndex:(NSUInteger)indexPath.row];
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self saveRules];
    [tableView reloadData];
}

@end

@implementation KPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    KPRulesController *rules = [[KPRulesController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:rules];
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
