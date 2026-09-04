#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <math.h>
#import "DWShared.h"

@interface DWWidgetManager : NSObject
@property(nonatomic,strong) UIView *view;
@property(nonatomic,weak) UIView *dashboard;
@property(nonatomic,weak) UIView *clockView;
@property(nonatomic,strong) UILabel *icon;
@property(nonatomic,strong) UILabel *label;
+ (instancetype)shared;
- (void)buildView;
- (void)reload;
- (void)attachToDashboard:(UIView *)dashboard;
- (void)attachToClock:(UIView *)clock;
- (void)attach;
@end

static BOOL DWWidgetEnabled(NSDictionary *m) {
    // Keep the widget opt-in, but if the key does not exist yet, default to NO.
    return m[DWMetaKeyWidgetEnabled] ? [m[DWMetaKeyWidgetEnabled] boolValue] : NO;
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
    if (!h) { [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]; h = [NSFileHandle fileHandleForWritingAtPath:path]; }
    if (h) { @try { [h seekToEndOfFile]; [h writeData:data]; [h closeFile]; } @catch (__unused id e) {} }
}

static void DWWidgetDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ [[DWWidgetManager shared] reload]; });
}

@implementation DWWidgetManager

+ (instancetype)shared {
    static DWWidgetManager *x; static dispatch_once_t once;
    dispatch_once(&once, ^{
        x=[DWWidgetManager new];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, DWWidgetDarwinCallback, DWReloadNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    });
    return x;
}

- (void)buildView {
    if (self.view) return;
    self.view=[[UIView alloc] initWithFrame:CGRectMake(0,0,190,52)];
    self.view.backgroundColor=[[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:0.86];
    self.view.layer.cornerRadius=18.0;
    self.view.layer.masksToBounds=YES;
    self.view.userInteractionEnabled=NO;
    self.view.hidden=YES;

    self.icon=[[UILabel alloc] initWithFrame:CGRectMake(14,7,38,38)];
    self.icon.font=[UIFont systemFontOfSize:24.0];
    self.icon.textAlignment=NSTextAlignmentCenter;

    self.label=[[UILabel alloc] initWithFrame:CGRectMake(54,6,120,40)];
    self.label.font=[UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    self.label.textAlignment=NSTextAlignmentLeft;
    self.label.adjustsFontSizeToFitWidth=YES;
    self.label.minimumScaleFactor=0.75;

    [self.view addSubview:self.icon];
    [self.view addSubview:self.label];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
}

- (void)reload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self buildView];
        NSDictionary *m=[NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
        BOOL enabled=DWWidgetEnabled(m);
        NSInteger type=[m[DWMetaKeyWidgetType] integerValue];
        NSString *text=m[DWMetaKeyWidgetText] ?: @"";

        if (type==0) {
            UIDevice.currentDevice.batteryMonitoringEnabled=YES;
            float level=UIDevice.currentDevice.batteryLevel;
            self.label.text=(level >= 0.0f)?[NSString stringWithFormat:@"%d%%",(int)roundf(level*100.0f)]:@"—";
            self.icon.text=@"⌁";
        } else if (type==1) {
            self.label.text=text.length?text:@"Thời tiết";
            self.icon.text=@"☂";
        } else {
            self.label.text=text.length?text:@"Depth Wallpaper";
            self.icon.text=@"✦";
        }

        if (self.clockView.window) {
            [self attachToClock:self.clockView];
        } else {
            [self attach];
        }

        self.view.hidden=!enabled;
        DWWidgetLog([NSString stringWithFormat:@"reload enabled=%@ type=%ld clock=%@ superview=%@", enabled?@"YES":@"NO", (long)type, self.clockView?NSStringFromClass(self.clockView.class):@"<nil>", self.view.superview?NSStringFromClass(self.view.superview.class):@"<nil>"]);
    });
}

- (void)batteryChanged:(NSNotification *)notification { [self reload]; }

- (UIView *)safeParentForClock:(UIView *)clock {
    if (!clock) return nil;
    UIView *p=clock.superview;
    if (!p) return nil;
    while (p.superview && p.clipsToBounds) p=p.superview;
    return p;
}

- (UIView *)directBranchForDescendant:(UIView *)descendant root:(UIView *)root {
    if (!descendant || !root) return nil;
    UIView *v=descendant;
    while (v.superview && v.superview != root) v=v.superview;
    return (v.superview==root)?v:nil;
}

- (void)placeRelativeToClock:(UIView *)clock inParent:(UIView *)parent {
    if (!clock || !parent || !self.view) return;
    CGRect clockFrame=[clock convertRect:clock.bounds toView:parent];
    if (CGRectIsEmpty(clockFrame) || parent.bounds.size.width<=1 || parent.bounds.size.height<=1) return;

    NSDictionary *m=[NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    CGFloat scale=m[DWMetaKeyWidgetScale] ? [m[DWMetaKeyWidgetScale] doubleValue] : 1.0;
    scale=MIN(2.0,MAX(0.6,scale));

    CGFloat defaultX=0.5;
    CGFloat defaultY=0.0;
    if (m[DWMetaKeyWidgetCenterX]) defaultX=[m[DWMetaKeyWidgetCenterX] doubleValue];
    if (m[DWMetaKeyWidgetCenterY]) defaultY=[m[DWMetaKeyWidgetCenterY] doubleValue];

    CGFloat width=190.0*scale, height=52.0*scale;
    CGFloat x=parent.bounds.size.width*defaultX;
    CGFloat y;
    if (m[DWMetaKeyWidgetCenterY]) {
        y=parent.bounds.size.height*defaultY;
    } else {
        y=CGRectGetMaxY(clockFrame)+44.0+height/2.0;
    }

    // Clamp so the widget remains on-screen without forcing it over the clock.
    x=MIN(parent.bounds.size.width-width/2.0-12.0,MAX(width/2.0+12.0,x));
    y=MIN(parent.bounds.size.height-height/2.0-12.0,MAX(CGRectGetMaxY(clockFrame)+height/2.0+10.0,y));

    self.view.bounds=(CGRect){CGPointZero,CGSizeMake(width,height)};
    self.view.center=CGPointMake(x,y);
    self.icon.frame=CGRectMake(14*scale,7*scale,38*scale,38*scale);
    self.label.frame=CGRectMake(54*scale,6*scale,120*scale,40*scale);
    self.icon.font=[UIFont systemFontOfSize:24.0*scale];
    self.label.font=[UIFont systemFontOfSize:18.0*scale weight:UIFontWeightSemibold];
}

- (void)attachToClock:(UIView *)clock {
    if (!clock) return;
    [self buildView];
    self.clockView=clock;

    UIView *parent=[self safeParentForClock:clock];
    if (!parent) parent=clock.superview ?: clock;
    self.dashboard=parent.window.rootViewController.view;

    if (self.view.superview != parent) {
        [self.view removeFromSuperview];
        [parent addSubview:self.view];
    }

    [self placeRelativeToClock:clock inParent:parent];

    // Keep widget above the clock branch, but never force it to the absolute top.
    UIView *clockBranch=[self directBranchForDescendant:clock root:parent];
    if (clockBranch && clockBranch != self.view) {
        [parent insertSubview:self.view aboveSubview:clockBranch];
    }

    NSDictionary *m=[NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    self.view.hidden=!DWWidgetEnabled(m);
    DWWidgetLog([NSString stringWithFormat:@"attach clock=%@ parent=%@ visible=%@ frame=%@", NSStringFromClass(clock.class), NSStringFromClass(parent.class), self.view.hidden?@"NO":@"YES", NSStringFromCGRect(self.view.frame)]);
}

- (void)attachToDashboard:(UIView *)dashboard {
    if (!dashboard) return;
    [self buildView];
    self.dashboard=dashboard;
    UIView *clock=nil;
    Class clockClass=NSClassFromString(@"SBFLockScreenDateView");
    if (clockClass) clock=[self find:dashboard cls:clockClass];
    if (clock) { [self attachToClock:clock]; return; }

    self.view.frame=CGRectMake((dashboard.bounds.size.width-190)/2.0, dashboard.bounds.size.height*0.62, 190, 52);
    if (self.view.superview != dashboard) { [self.view removeFromSuperview]; [dashboard addSubview:self.view]; }
    NSDictionary *m=[NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    self.view.hidden=!DWWidgetEnabled(m);
    DWWidgetLog([NSString stringWithFormat:@"dashboard fallback=%@ visible=%@", NSStringFromClass(dashboard.class), self.view.hidden?@"NO":@"YES"]);
}

- (void)attach {
    if (self.clockView.window) { [self attachToClock:self.clockView]; return; }
    if (self.dashboard.window) { [self attachToDashboard:self.dashboard]; return; }

    // Scene-aware search: SpringBoard may not expose the dashboard via UIApplication.windows.
    Class dash=NSClassFromString(@"SBDashBoardView");
    if (!dash) return;
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        UIView *root=w.rootViewController.view;
        UIView *found=[self find:root cls:dash];
        if (found) { [self attachToDashboard:found]; return; }
    }
}

- (UIView *)find:(UIView *)root cls:(Class)cls {
    if (!root) return nil;
    if ([root isKindOfClass:cls]) return root;
    for (UIView *v in [root.subviews copy]) {
        UIView *f=[self find:v cls:cls]; if(f)return f;
    }
    return nil;
}

%end

%hook SBFLockScreenDateView

- (void)didMoveToWindow {
    %orig;
    UIView *clock=(UIView *)self;
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
    UIView *view=(UIView *)self;
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
    UIViewController *vc=(UIViewController *)self;
    [[DWWidgetManager shared] attachToDashboard:vc.view];
    [[DWWidgetManager shared] reload];
}

- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *vc=(UIViewController *)self;
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
