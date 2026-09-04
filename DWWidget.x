/*
 * DepthWallpaper 1.6.6
 * Lock Screen widget group: three horizontal slots.
 *
 * Important: this file intentionally does not modify the cutout renderer.
 * It only manages the separate widget layer.
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
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

static CGFloat DWWidgetBackgroundAlpha(NSDictionary *m) {
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
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    if (handle) {
        @try { [handle seekToEndOfFile]; [handle writeData:data]; [handle closeFile]; } @catch (__unused id e) {}
    }
}

static void DWWidgetDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ [[DWWidgetManager shared] reload]; });
}

static BOOL DWWidgetLooksLikeNotification(UIView *view) {
    if (!view) return NO;
    NSString *name = NSStringFromClass(view.class).lowercaseString;
    return [name containsString:@"ncnotification"] ||
           [name containsString:@"notificationlist"] ||
           [name containsString:@"notificationcollection"] ||
           [name containsString:@"notificationstack"] ||
           [name containsString:@"bulletinlist"] ||
           [name containsString:@"dashboardscombinedlist"] ||
           [name containsString:@"lockscreencombinedlist"];
}

static UIView *DWWidgetFindView(UIView *root, BOOL (^matcher)(UIView *)) {
    if (!root) return nil;
    if (matcher && matcher(root)) return root;
    for (UIView *sub in [root.subviews copy]) {
        UIView *found = DWWidgetFindView(sub, matcher);
        if (found) return found;
    }
    return nil;
}

static UIView *DWWidgetDashboardRoot(UIView *view) {
    UIView *candidate = view;
    while (candidate) {
        NSString *name = NSStringFromClass(candidate.class);
        if ([name isEqualToString:@"SBDashBoardView"] || [name containsString:@"DashBoardView"]) return candidate;
        candidate = candidate.superview;
    }
    return view.window.rootViewController.view ?: view;
}

static UIView *DWWidgetDirectChild(UIView *descendant, UIView *root) {
    if (!descendant || !root) return nil;
    UIView *v = descendant;
    while (v.superview && v.superview != root) v = v.superview;
    return v.superview == root ? v : nil;
}

static UIView *DWWidgetLowestCommonAncestor(UIView *a, UIView *b) {
    if (!a || !b) return nil;
    NSMutableSet *ancestors = [NSMutableSet set];
    UIView *v = a;
    while (v) { [ancestors addObject:v]; v = v.superview; }
    v = b;
    while (v) {
        if ([ancestors containsObject:v]) return v;
        v = v.superview;
    }
    return nil;
}

static UIView *DWWidgetSafeAncestor(UIView *view) {
    UIView *p = view;
    while (p.superview && p.clipsToBounds) p = p.superview;
    return p;
}

static UIView *DWWidgetCutoutHost(void) {
    // Access the already-working cutout manager at runtime without changing it.
    Class cls = NSClassFromString(@"DWManager");
    if (!cls) return nil;

    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    id manager = nil;
    if ([cls respondsToSelector:sharedSel]) {
        manager = ((id (*)(id, SEL))objc_msgSend)(cls, sharedSel);
    }
    if (!manager) return nil;

    @try {
        id host = [manager valueForKey:@"hostView"];
        if ([host isKindOfClass:[UIView class]]) return host;
    } @catch (__unused id e) {}
    return nil;
}

static UIView *DWWidgetChooseParent(UIView *clock, UIView *notification, UIView *cutoutHost, UIView *dashboard) {
    UIView *parent = nil;

    // Prefer a common ancestor containing the clock and existing depth cutout.
    if (clock && cutoutHost && clock.window == cutoutHost.window) {
        parent = DWWidgetLowestCommonAncestor(clock, cutoutHost);
    }

    // Bring notification into the same ordering domain when possible.
    if (parent && notification && notification.window == clock.window) {
        UIView *common = DWWidgetLowestCommonAncestor(parent, notification);
        if (common) parent = common;
    }

    if (!parent && clock) parent = clock.superview;
    if (!parent) parent = dashboard;

    return DWWidgetSafeAncestor(parent);
}

@implementation DWWidgetManager

+ (instancetype)shared {
    static DWWidgetManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [DWWidgetManager new];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        DWWidgetDarwinCallback,
                                        DWReloadNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    });
    return manager;
}

- (void)buildView {
    if (self.view) return;

    // One group containing three horizontal widget cells.
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 360, 108)];
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.86];
    self.view.layer.cornerRadius = 22.0;
    self.view.layer.masksToBounds = YES;
    self.view.userInteractionEnabled = NO;
    self.view.hidden = YES;
    self.view.alpha = 1.0; // Never fade text/icons with transparency setting.

    self.icons = [NSMutableArray arrayWithCapacity:3];
    self.labels = [NSMutableArray arrayWithCapacity:3];

    for (NSInteger i = 0; i < 3; i++) {
        CGFloat cellX = i * 120.0;
        UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(cellX, 0, 120, 108)];
        cell.backgroundColor = UIColor.clearColor;
        cell.userInteractionEnabled = NO;
        [self.view addSubview:cell];

        UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(6, 28, 34, 34)];
        icon.font = [UIFont systemFontOfSize:21.0];
        icon.textAlignment = NSTextAlignmentCenter;
        icon.textColor = UIColor.whiteColor;
        icon.backgroundColor = UIColor.clearColor;

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(40, 24, 74, 48)];
        label.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
        label.textAlignment = NSTextAlignmentCenter;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.60;
        label.textColor = UIColor.whiteColor;
        label.numberOfLines = 2;
        label.backgroundColor = UIColor.clearColor;

        [cell addSubview:icon];
        [cell addSubview:label];
        [self.icons addObject:icon];
        [self.labels addObject:label];

        if (i < 2) {
            UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(cellX + 119.0, 20, 1, 68)];
            separator.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10];
            [self.view addSubview:separator];
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryChanged:)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
}

- (void)reload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self buildView];

        NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
        BOOL enabled = DWWidgetEnabled(m);
        CGFloat backgroundAlpha = DWWidgetBackgroundAlpha(m);

        // IMPORTANT: only the background is transparent. Text and icons remain opaque.
        self.view.alpha = 1.0;
        self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:backgroundAlpha];

        for (NSInteger i = 0; i < 3; i++) {
            NSInteger slot = i + 1;
            NSInteger type = DWWidgetTypeForSlot(m, slot);
            NSString *text = DWWidgetTextForSlot(m, slot);
            UILabel *icon = self.icons[i];
            UILabel *label = self.labels[i];

            if (type == 0) {
                UIDevice.currentDevice.batteryMonitoringEnabled = YES;
                float level = UIDevice.currentDevice.batteryLevel;
                NSString *value = (level >= 0.0f)
                    ? [NSString stringWithFormat:@"Pin  %d%%", (int)roundf(level * 100.0f)]
                    : @"Pin  —";
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

        [self attach];
        self.view.hidden = !enabled;

        DWWidgetLog([NSString stringWithFormat:@"reload enabled=%@ transparency=%0.0f%% superview=%@",
                     enabled ? @"YES" : @"NO",
                     backgroundAlpha * 100.0,
                     self.view.superview ? NSStringFromClass(self.view.superview.class) : @"<nil>"]);
    });
}

- (void)batteryChanged:(NSNotification *)notification {
    [self reload];
}

- (void)placeRelativeToClock:(UIView *)clock inParent:(UIView *)parent dashboard:(UIView *)dashboard {
    if (!clock || !parent || !dashboard || !self.view) return;

    CGRect dashboardRect = [dashboard convertRect:dashboard.bounds toView:parent];
    CGRect clockFrame = [clock convertRect:clock.bounds toView:parent];
    if (CGRectIsEmpty(dashboardRect) || CGRectIsEmpty(clockFrame) || parent.bounds.size.width <= 1 || parent.bounds.size.height <= 1) return;

    NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    CGFloat scale = m[DWMetaKeyWidgetScale] ? [m[DWMetaKeyWidgetScale] doubleValue] : 1.0;
    scale = MIN(1.4, MAX(0.7, scale));

    CGFloat xRatio = m[DWMetaKeyWidgetCenterX] ? [m[DWMetaKeyWidgetCenterX] doubleValue] : 0.5;
    CGFloat yRatio = m[DWMetaKeyWidgetCenterY] ? [m[DWMetaKeyWidgetCenterY] doubleValue] : -1.0;
    CGFloat width = 360.0 * scale;
    CGFloat height = 108.0 * scale;

    CGFloat x = CGRectGetMinX(dashboardRect) + dashboardRect.size.width * xRatio;
    CGFloat y = (yRatio >= 0.0)
        ? CGRectGetMinY(dashboardRect) + dashboardRect.size.height * yRatio
        : CGRectGetMaxY(clockFrame) + 30.0 + height / 2.0;

    CGFloat minX = CGRectGetMinX(dashboardRect) + width / 2.0 + 8.0;
    CGFloat maxX = CGRectGetMaxX(dashboardRect) - width / 2.0 - 8.0;
    CGFloat minY = CGRectGetMaxY(clockFrame) + height / 2.0 + 10.0;
    CGFloat maxY = CGRectGetMaxY(dashboardRect) - height / 2.0 - 8.0;

    if (maxX >= minX) x = MIN(maxX, MAX(minX, x));
    if (maxY >= minY) y = MIN(maxY, MAX(minY, y));

    self.view.bounds = (CGRect){ CGPointZero, CGSizeMake(width, height) };
    self.view.center = CGPointMake(x, y);

    CGFloat cellWidth = 120.0 * scale;
    for (NSInteger i = 0; i < self.icons.count; i++) {
        UILabel *icon = self.icons[i];
        UILabel *label = self.labels[i];
        CGFloat cellX = i * cellWidth;
        icon.frame = CGRectMake(cellX + 6 * scale, 28 * scale, 34 * scale, 34 * scale);
        label.frame = CGRectMake(cellX + 40 * scale, 24 * scale, 74 * scale, 48 * scale);
        icon.font = [UIFont systemFontOfSize:21.0 * scale];
        label.font = [UIFont systemFontOfSize:15.5 * scale weight:UIFontWeightSemibold];
    }
}

- (void)reorderAboveCutoutAndClockBelowNotifications:(UIView *)parent
                                               clock:(UIView *)clock
                                           cutoutHost:(UIView *)cutoutHost
                                        notification:(UIView *)notification {
    if (!parent || !self.view) return;

    UIView *clockBranch = DWWidgetDirectChild(clock, parent);
    UIView *cutoutBranch = DWWidgetDirectChild(cutoutHost, parent);
    UIView *notificationBranch = DWWidgetDirectChild(notification, parent);

    if (notificationBranch == self.view) notificationBranch = nil;
    if (cutoutBranch == self.view) cutoutBranch = nil;
    if (clockBranch == self.view) clockBranch = nil;

    // Desired order: clock < cutout < widget < notification.
    if (clockBranch && clockBranch != cutoutBranch) {
        [parent insertSubview:self.view aboveSubview:clockBranch];
    }
    if (cutoutBranch && cutoutBranch != self.view) {
        [parent insertSubview:self.view aboveSubview:cutoutBranch];
    }
    if (notificationBranch && notificationBranch != self.view) {
        [parent insertSubview:self.view belowSubview:notificationBranch];
    }

    if (!clockBranch && !cutoutBranch && !notificationBranch) {
        [parent addSubview:self.view];
    }
}

- (void)attachToClock:(UIView *)clock {
    if (!clock || !clock.window) return;
    [self buildView];
    self.clockView = clock;

    UIView *dashboard = DWWidgetDashboardRoot(clock);
    UIView *cutoutHost = DWWidgetCutoutHost();
    UIView *notification = DWWidgetFindView(dashboard, ^BOOL(UIView *candidate) {
        return candidate != self.view && DWWidgetLooksLikeNotification(candidate);
    });

    UIView *parent = DWWidgetChooseParent(clock, notification, cutoutHost, dashboard);
    if (!parent) return;
    self.dashboard = dashboard;

    if (self.view.superview != parent) {
        [self.view removeFromSuperview];
        [parent addSubview:self.view];
    }

    [self placeRelativeToClock:clock inParent:parent dashboard:dashboard];
    [self reorderAboveCutoutAndClockBelowNotifications:parent
                                                  clock:clock
                                              cutoutHost:cutoutHost
                                           notification:notification];

    NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    self.view.hidden = !DWWidgetEnabled(m);
    self.view.alpha = 1.0;
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:DWWidgetBackgroundAlpha(m)];

    DWWidgetLog([NSString stringWithFormat:@"attach parent=%@ clock=%@ cutout=%@ notification=%@ visible=%@ frame=%@",
                 NSStringFromClass(parent.class),
                 NSStringFromClass(clock.class),
                 cutoutHost ? NSStringFromClass(cutoutHost.class) : @"<none>",
                 notification ? NSStringFromClass(notification.class) : @"<none>",
                 self.view.hidden ? @"NO" : @"YES",
                 NSStringFromCGRect(self.view.frame)]);
}

- (void)attachToDashboard:(UIView *)dashboard {
    if (!dashboard || !dashboard.window) return;
    [self buildView];
    self.dashboard = dashboard;

    UIView *clock = DWWidgetFindView(dashboard, ^BOOL(UIView *candidate) {
        NSString *name = NSStringFromClass(candidate.class);
        return [name isEqualToString:@"SBFLockScreenDateView"] || [name isEqualToString:@"SBUILockScreenDateView"] || [name containsString:@"LockScreenDateView"];
    });
    if (clock) {
        [self attachToClock:clock];
        return;
    }

    NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    CGFloat alpha = DWWidgetBackgroundAlpha(m);
    self.view.alpha = 1.0;
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:alpha];
    self.view.hidden = !DWWidgetEnabled(m);

    CGFloat width = 360.0;
    CGFloat height = 108.0;
    self.view.bounds = (CGRect){ CGPointZero, CGSizeMake(width, height) };
    self.view.center = CGPointMake(CGRectGetMidX(dashboard.bounds), CGRectGetMaxY(dashboard.bounds) * 0.62);
    if (self.view.superview != dashboard) {
        [self.view removeFromSuperview];
        [dashboard addSubview:self.view];
    }
    DWWidgetLog([NSString stringWithFormat:@"dashboard fallback=%@ visible=%@", NSStringFromClass(dashboard.class), self.view.hidden ? @"NO" : @"YES"]);
}

- (void)attach {
    if (self.clockView.window) {
        [self attachToClock:self.clockView];
        return;
    }
    if (self.dashboard.window) {
        [self attachToDashboard:self.dashboard];
        return;
    }

    Class dash = NSClassFromString(@"SBDashBoardView");
    if (!dash) return;

    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        UIView *root = window.rootViewController.view;
        UIView *found = [self find:root cls:dash];
        if (found) {
            [self attachToDashboard:found];
            return;
        }
    }
}

- (UIView *)find:(UIView *)root cls:(Class)cls {
    if (!root) return nil;
    if ([root isKindOfClass:cls]) return root;
    for (UIView *sub in [root.subviews copy]) {
        UIView *found = [self find:sub cls:cls];
        if (found) return found;
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
    UIView *clock = (UIView *)self;
    if (clock.window) [[DWWidgetManager shared] attachToClock:clock];
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
    UIView *view = (UIView *)self;
    if (view.window) [[DWWidgetManager shared] attachToDashboard:view];
}
%end

%hook SBDashBoardViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIViewController *vc = (UIViewController *)self;
    if (vc.view.window) {
        [[DWWidgetManager shared] attachToDashboard:vc.view];
        [[DWWidgetManager shared] reload];
    }
}
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *vc = (UIViewController *)self;
    if (vc.view.window) [[DWWidgetManager shared] attachToDashboard:vc.view];
}
%end

%hook NCNotificationListCollectionView
- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    if (view.window) {
        [[DWWidgetManager shared] reload];
    }
}
%end

%hook SBDashBoardCombinedListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *vc = (UIViewController *)self;
    if (vc.view.window) [[DWWidgetManager shared] reload];
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[DWWidgetManager shared] buildView];
    [[DWWidgetManager shared] reload];
}
%end
