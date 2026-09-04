#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <math.h>
#import "DWShared.h"

@interface DWWidgetManager : NSObject
@property(nonatomic,strong) UIView *view;
@property(nonatomic,weak) UIView *dashboard;
@property(nonatomic,weak) UIView *clockView;
@property(nonatomic,strong) NSMutableArray<UILabel *> *icons;
@property(nonatomic,strong) NSMutableArray<UILabel *> *labels;
+ (instancetype)shared;
- (void)buildView;
- (void)reload;
- (void)attachToDashboard:(UIView *)dashboard;
- (void)attachToClock:(UIView *)clock;
- (void)attach;
@end

static BOOL DWWidgetEnabled(NSDictionary *m) {
    return m[DWMetaKeyWidgetEnabled] ? [m[DWMetaKeyWidgetEnabled] boolValue] : NO;
}

static NSInteger DWWidgetTypeForSlot(NSDictionary *m, NSInteger slot) {
    NSString *key = slot == 1 ? DWMetaKeyWidget1Type : (slot == 2 ? DWMetaKeyWidget2Type : DWMetaKeyWidget3Type);
    if (m[key] != nil) return [m[key] integerValue];
    if (slot == 1 && m[DWMetaKeyWidgetType] != nil) return [m[DWMetaKeyWidgetType] integerValue];
    return slot == 1 ? 0 : (slot == 2 ? 1 : 2);
}

static NSString *DWWidgetTextForSlot(NSDictionary *m, NSInteger slot) {
    NSString *key = slot == 1 ? DWMetaKeyWidget1Text : (slot == 2 ? DWMetaKeyWidget2Text : DWMetaKeyWidget3Text);
    if (m[key] != nil) return m[key];
    if (slot == 1 && m[DWMetaKeyWidgetText] != nil) return m[DWMetaKeyWidgetText];
    return @"";
}

static CGFloat DWWidgetTransparency(NSDictionary *m) {
    if (m[DWMetaKeyWidgetTransparency] != nil) {
        return MIN(1.0, MAX(0.0, [m[DWMetaKeyWidgetTransparency] doubleValue] / 100.0));
    }
    return 0.86;
}

static void DWWidgetLog(NSString *message) {
    if (!message) return;
    NSString *dir = @"/var/mobile/Library/Logs";
    NSString *path = @"/var/mobile/Library/Logs/DepthWallpaperTweak.log";
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *line = [NSString stringWithFormat:@"[Widget] %@ %@\n", [NSDate date], message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;
    NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!h) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        h = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    if (h) {
        @try { [h seekToEndOfFile]; [h writeData:data]; [h closeFile]; } @catch (__unused id e) {}
    }
}

static void DWWidgetDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ [[DWWidgetManager shared] reload]; });
}

@implementation DWWidgetManager

+ (instancetype)shared {
    static DWWidgetManager *x;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        x = [DWWidgetManager new];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, DWWidgetDarwinCallback, DWReloadNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    });
    return x;
}

- (void)buildView {
    if (self.view) return;

    // One grouped container containing three small widgets.
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 285, 184)];
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    self.view.layer.cornerRadius = 20.0;
    self.view.layer.masksToBounds = YES;
    self.view.userInteractionEnabled = NO;
    self.view.hidden = YES;
    self.view.alpha = 0.86;

    self.icons = [NSMutableArray arrayWithCapacity:3];
    self.labels = [NSMutableArray arrayWithCapacity:3];

    for (NSInteger i = 0; i < 3; i++) {
        CGFloat y = 8.0 + i * 58.0;
        UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(12, y + 6, 42, 40)];
        icon.font = [UIFont systemFontOfSize:23.0];
        icon.textAlignment = NSTextAlignmentCenter;
        icon.textColor = [UIColor whiteColor];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(58, y + 4, 210, 44)];
        label.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
        label.textAlignment = NSTextAlignmentLeft;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.72;
        label.textColor = [UIColor whiteColor];
        label.numberOfLines = 1;

        UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(14, y + 55, 257, 1)];
        separator.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12];
        if (i == 2) separator.hidden = YES;

        [self.view addSubview:icon];
        [self.view addSubview:label];
        [self.view addSubview:separator];
        [self.icons addObject:icon];
        [self.labels addObject:label];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
}

- (void)reload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self buildView];

        NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
        BOOL enabled = DWWidgetEnabled(m);
        self.view.alpha = DWWidgetTransparency(m);

        for (NSInteger i = 0; i < 3; i++) {
            NSInteger slot = i + 1;
            NSInteger type = DWWidgetTypeForSlot(m, slot);
            NSString *text = DWWidgetTextForSlot(m, slot);
            UILabel *icon = self.icons[i];
            UILabel *label = self.labels[i];

            if (type == 0) {
                UIDevice.currentDevice.batteryMonitoringEnabled = YES;
                float level = UIDevice.currentDevice.batteryLevel;
                NSString *value = (level >= 0.0f) ? [NSString stringWithFormat:@"Pin  %d%%", (int)roundf(level * 100.0f)] : @"Pin  —";
                icon.text = @"▣";
                label.text = value;
            } else if (type == 1) {
                icon.text = @"☂";
                label.text = text.length ? text : @"Thời tiết";
            } else {
                icon.text = @"✦";
                label.text = text.length ? text : @"Depth Wallpaper";
            }
        }

        if (self.clockView.window) {
            [self attachToClock:self.clockView];
        } else {
            [self attach];
        }

        self.view.hidden = !enabled;
        DWWidgetLog([NSString stringWithFormat:@"reload enabled=%@ types=%ld/%ld/%ld transparency=%.0f%% superview=%@",
                     enabled ? @"YES" : @"NO",
                     (long)DWWidgetTypeForSlot(m, 1), (long)DWWidgetTypeForSlot(m, 2), (long)DWWidgetTypeForSlot(m, 3),
                     DWWidgetTransparency(m) * 100.0,
                     self.view.superview ? NSStringFromClass(self.view.superview.class) : @"<nil>"]);
    });
}

- (void)batteryChanged:(NSNotification *)notification { [self reload]; }

- (UIView *)safeParentForClock:(UIView *)clock {
    if (!clock) return nil;
    UIView *p = clock.superview;
    if (!p) return nil;
    while (p.superview && p.clipsToBounds) p = p.superview;
    return p;
}

- (UIView *)directBranchForDescendant:(UIView *)descendant root:(UIView *)root {
    if (!descendant || !root) return nil;
    UIView *v = descendant;
    while (v.superview && v.superview != root) v = v.superview;
    return (v.superview == root) ? v : nil;
}

- (void)placeRelativeToClock:(UIView *)clock inParent:(UIView *)parent {
    if (!clock || !parent || !self.view) return;
    CGRect clockFrame = [clock convertRect:clock.bounds toView:parent];
    if (CGRectIsEmpty(clockFrame) || parent.bounds.size.width <= 1 || parent.bounds.size.height <= 1) return;

    NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    CGFloat scale = m[DWMetaKeyWidgetScale] ? [m[DWMetaKeyWidgetScale] doubleValue] : 1.0;
    scale = MIN(1.4, MAX(0.7, scale));

    CGFloat defaultX = m[DWMetaKeyWidgetCenterX] ? [m[DWMetaKeyWidgetCenterX] doubleValue] : 0.5;
    CGFloat defaultY = m[DWMetaKeyWidgetCenterY] ? [m[DWMetaKeyWidgetCenterY] doubleValue] : 0.0;

    CGFloat width = 285.0 * scale;
    CGFloat height = 184.0 * scale;
    CGFloat x = parent.bounds.size.width * defaultX;
    CGFloat y;
    if (m[DWMetaKeyWidgetCenterY]) {
        y = parent.bounds.size.height * defaultY;
    } else {
        y = CGRectGetMaxY(clockFrame) + 28.0 + height / 2.0;
    }

    x = MIN(parent.bounds.size.width - width / 2.0 - 12.0, MAX(width / 2.0 + 12.0, x));
    y = MIN(parent.bounds.size.height - height / 2.0 - 12.0, MAX(CGRectGetMaxY(clockFrame) + height / 2.0 + 10.0, y));

    self.view.bounds = (CGRect){ CGPointZero, CGSizeMake(width, height) };
    self.view.center = CGPointMake(x, y);

    for (NSInteger i = 0; i < self.icons.count; i++) {
        UILabel *icon = self.icons[i];
        UILabel *label = self.labels[i];
        CGFloat rowScale = scale;
        CGFloat rowY = 8.0 + i * 58.0;
        icon.frame = CGRectMake(12 * rowScale, (rowY + 6) * rowScale, 42 * rowScale, 40 * rowScale);
        label.frame = CGRectMake(58 * rowScale, (rowY + 4) * rowScale, 210 * rowScale, 44 * rowScale);
        icon.font = [UIFont systemFontOfSize:23.0 * rowScale];
        label.font = [UIFont systemFontOfSize:17.0 * rowScale weight:UIFontWeightSemibold];
    }
}

- (void)attachToClock:(UIView *)clock {
    if (!clock) return;
    [self buildView];
    self.clockView = clock;

    UIView *parent = [self safeParentForClock:clock];
    if (!parent) parent = clock.superview ?: clock;
    self.dashboard = parent.window.rootViewController.view;

    if (self.view.superview != parent) {
        [self.view removeFromSuperview];
        [parent addSubview:self.view];
    }

    [self placeRelativeToClock:clock inParent:parent];

    UIView *clockBranch = [self directBranchForDescendant:clock root:parent];
    if (clockBranch && clockBranch != self.view) {
        [parent insertSubview:self.view aboveSubview:clockBranch];
    }

    NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    self.view.hidden = !DWWidgetEnabled(m);
    self.view.alpha = DWWidgetTransparency(m);
    DWWidgetLog([NSString stringWithFormat:@"attach clock=%@ parent=%@ visible=%@ alpha=%.2f frame=%@",
                 NSStringFromClass(clock.class), NSStringFromClass(parent.class), self.view.hidden ? @"NO" : @"YES", self.view.alpha, NSStringFromCGRect(self.view.frame)]);
}

- (void)attachToDashboard:(UIView *)dashboard {
    if (!dashboard) return;
    [self buildView];
    self.dashboard = dashboard;
    UIView *clock = nil;
    Class clockClass = NSClassFromString(@"SBFLockScreenDateView");
    if (clockClass) clock = [self find:dashboard cls:clockClass];
    if (clock) { [self attachToClock:clock]; return; }

    self.view.frame = CGRectMake((dashboard.bounds.size.width - 285) / 2.0, dashboard.bounds.size.height * 0.60, 285, 184);
    if (self.view.superview != dashboard) { [self.view removeFromSuperview]; [dashboard addSubview:self.view]; }
    NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    self.view.hidden = !DWWidgetEnabled(m);
    self.view.alpha = DWWidgetTransparency(m);
    DWWidgetLog([NSString stringWithFormat:@"dashboard fallback=%@ visible=%@", NSStringFromClass(dashboard.class), self.view.hidden ? @"NO" : @"YES"]);
}

- (void)attach {
    if (self.clockView.window) { [self attachToClock:self.clockView]; return; }
    if (self.dashboard.window) { [self attachToDashboard:self.dashboard]; return; }

    Class dash = NSClassFromString(@"SBDashBoardView");
    if (!dash) return;
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        UIView *root = w.rootViewController.view;
        UIView *found = [self find:root cls:dash];
        if (found) { [self attachToDashboard:found]; return; }
    }
}

- (UIView *)find:(UIView *)root cls:(Class)cls {
    if (!root) return nil;
    if ([root isKindOfClass:cls]) return root;
    for (UIView *v in [root.subviews copy]) {
        UIView *f = [self find:v cls:cls];
        if (f) return f;
    }
    return nil;
}

@end

%hook SBFLockScreenDateView
- (void)didMoveToWindow {
    %orig;
    UIView *clock = (UIView *)self;
    if (clock.window) {
        [[DWWidgetManager shared] attachToClock:clock];
        [[DWWidgetManager shared] reload];
    }
}
- (void)layoutSubviews {
    %orig;
    [[DWWidgetManager shared] attachToClock:(UIView *)self];
}
%end

%hook SBDashBoardView
- (void)didMoveToWindow {
    %orig;
    UIView *view = (UIView *)self;
    if (view.window) {
        [[DWWidgetManager shared] attachToDashboard:view];
        [[DWWidgetManager shared] reload];
    }
}
- (void)layoutSubviews {
    %orig;
    [[DWWidgetManager shared] attach];
}
%end

%hook SBDashBoardViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIViewController *vc = (UIViewController *)self;
    [[DWWidgetManager shared] attachToDashboard:vc.view];
    [[DWWidgetManager shared] reload];
}
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *vc = (UIViewController *)self;
    [[DWWidgetManager shared] attachToDashboard:vc.view];
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[DWWidgetManager shared] buildView];
    [[DWWidgetManager shared] reload];
}
%end
