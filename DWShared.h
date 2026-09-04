// DWShared.h — dung chung giua DepthWallpaperApp va Tweak.x, giu 2 ben khop nhau.
#ifndef DWShared_h
#define DWShared_h

static NSString * const DWSharedDirectory = @"/var/mobile/Library/Application Support/DepthWallpaper";
static NSString * const DWCutoutImagePath = @"/var/mobile/Library/Application Support/DepthWallpaper/cutout.png";
static NSString * const DWMetadataPath    = @"/var/mobile/Library/Application Support/DepthWallpaper/meta.plist";
static CFStringRef const DWReloadNotification = CFSTR("com.yourname.depthwallpaper/reload");

static NSString * const DWMetaKeyYOffsetRatio = @"YOffsetRatio";
static NSString * const DWMetaKeyScale        = @"Scale";
static NSString * const DWMetaKeyEnabled      = @"Enabled";
static NSString * const DWMetaKeyAspectMatch  = @"AspectMatch";
static NSString * const DWMetaKeyManualFullResolution = @"ManualFullResolution";
static NSString * const DWMetaKeyCutoutCenterX = @"CutoutCenterX";
static NSString * const DWMetaKeyCutoutCenterY = @"CutoutCenterY";
static NSString * const DWMetaKeyCutoutScale   = @"CutoutScale";

static NSString * const DWWallpaperImagePath = @"/var/mobile/Library/Application Support/DepthWallpaper/wallpaper.png";
static NSString * const DWMetaKeyWallpaperWidth  = @"WallpaperWidth";
static NSString * const DWMetaKeyWallpaperHeight = @"WallpaperHeight";
static NSString * const DWMetaKeyCutoutWidth    = @"CutoutWidth";
static NSString * const DWMetaKeyCutoutHeight   = @"CutoutHeight";

// v1.6 widget settings. Independent from the cutout renderer.
static NSString * const DWMetaKeyWidgetEnabled = @"WidgetEnabled";
static NSString * const DWMetaKeyWidgetType = @"WidgetType"; // legacy slot-1 type
static NSString * const DWMetaKeyWidgetText = @"WidgetText"; // legacy slot-1 text
static NSString * const DWMetaKeyWidgetScale = @"WidgetScale";
static NSString * const DWMetaKeyWidgetCenterX = @"WidgetCenterX";
static NSString * const DWMetaKeyWidgetCenterY = @"WidgetCenterY";
static NSString * const DWMetaKeyWidgetTransparency = @"WidgetTransparency"; // 0-100, default 86

static NSString * const DWMetaKeyWidget1Type = @"Widget1Type";
static NSString * const DWMetaKeyWidget2Type = @"Widget2Type";
static NSString * const DWMetaKeyWidget3Type = @"Widget3Type";
static NSString * const DWMetaKeyWidget1Text = @"Widget1Text";
static NSString * const DWMetaKeyWidget2Text = @"Widget2Text";
static NSString * const DWMetaKeyWidget3Text = @"Widget3Text";

#endif
