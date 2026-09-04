#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <math.h>
#import "DWShared.h"

@interface DWWidgetManager : NSObject
@property(nonatomic,strong) UIView *view;
@property(nonatomic,weak) UIView *dashboard;
@property(nonatomic,strong) UILabel *icon;
@property(nonatomic,strong) UILabel *label;
+ (instancetype)shared;
- (void)reload;
- (void)attachToDashboard:(UIView *)dashboard;
@end

static BOOL DWWidgetEnabled(NSDictionary *m) { return [m[DWMetaKeyWidgetEnabled] boolValue]; }

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

- (void)reload {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *m=[NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
        if (!self.view) [self buildView];
        [self attach];
        self.view.hidden=!DWWidgetEnabled(m);
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
    });
}

- (void)batteryChanged:(NSNotification *)notification { [self reload]; }

- (void)buildView {
    self.view=[[UIView alloc] initWithFrame:CGRectMake(0,0,190,52)];
    self.view.backgroundColor=[[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:0.78];
    self.view.layer.cornerRadius=18.0; self.view.layer.masksToBounds=YES; self.view.userInteractionEnabled=NO;
    self.icon=[[UILabel alloc] initWithFrame:CGRectMake(14,7,38,38)]; self.icon.font=[UIFont systemFontOfSize:24]; self.icon.textAlignment=NSTextAlignmentCenter;
    self.label=[[UILabel alloc] initWithFrame:CGRectMake(54,6,120,40)]; self.label.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]; self.label.textAlignment=NSTextAlignmentLeft;
    [self.view addSubview:self.icon]; [self.view addSubview:self.label];
    [self attach];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
}

- (void)attachToDashboard:(UIView *)dashboard {
    if (!dashboard) return;
    self.dashboard = dashboard;
    if (!self.view) [self buildView];
    if (self.view.superview != dashboard) [dashboard addSubview:self.view];
    CGSize s = dashboard.bounds.size;
    if (s.width <= 0 || s.height <= 0) return;
    self.view.center = CGPointMake(s.width / 2.0, MIN(300.0, MAX(190.0, s.height * 0.27)));
    self.view.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [dashboard bringSubviewToFront:self.view];
}

- (void)attach {
    if (self.dashboard) { [self attachToDashboard:self.dashboard]; return; }
    Class dash = NSClassFromString(@"SBDashBoardView");
    if (!dash) return;
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        UIView *root = w.rootViewController.view;
        UIView *found = [self find:root cls:dash];
        if (found) { [self attachToDashboard:found]; return; }
    }
}
- (UIView *)find:(UIView *)root cls:(Class)cls {
    if (!root) return nil; if ([root isKindOfClass:cls]) return root;
    for (UIView *v in [root.subviews copy]) { UIView *f=[self find:v cls:cls]; if(f)return f; }
    return nil;
}

@end

%hook SBDashBoardView

- (void)didMoveToWindow {
    %orig;
    if (((UIView *)self).window) {
        [[DWWidgetManager shared] reload];
        dispatch_async(dispatch_get_main_queue(), ^{ [[DWWidgetManager shared] attach]; });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [[DWWidgetManager shared] reload]; });
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
    [[DWWidgetManager shared] attachToDashboard:self.view];
    [[DWWidgetManager shared] reload];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DWWidgetManager shared] attachToDashboard:self.view];
        [[DWWidgetManager shared] reload];
    });
}

- (void)viewDidLayoutSubviews {
    %orig;
    [[DWWidgetManager shared] attachToDashboard:self.view];
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[DWWidgetManager shared] reload];
}

%end
