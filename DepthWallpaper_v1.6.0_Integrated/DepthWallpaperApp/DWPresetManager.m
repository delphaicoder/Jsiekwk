#import "DWPresetManager.h"
#import "../DWShared.h"

static NSString * const DWPresetsDirectoryName = @"Presets";
static NSInteger const DWMaxPresets = 20;

@implementation DWPresetManager

+ (instancetype)sharedManager {
    static DWPresetManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [DWPresetManager new]; });
    return manager;
}

- (NSString *)directory {
    NSString *path = [DWSharedDirectory stringByAppendingPathComponent:DWPresetsDirectoryName];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}

- (NSArray<NSDictionary *> *)presets {
    NSMutableArray *items = [NSMutableArray array];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *dirs = [fm contentsOfDirectoryAtPath:[self directory] error:nil];
    for (NSString *name in dirs) {
        NSString *dir = [[self directory] stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:dir isDirectory:&isDir] || !isDir) continue;
        NSString *metaPath = [dir stringByAppendingPathComponent:@"meta.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath] ?: @{};
        NSString *displayName = meta[@"PresetName"];
        NSInteger index = [name integerValue];
        if (index > 0 && index <= DWMaxPresets) {
            [items addObject:@{ @"index": @(index), @"name": displayName.length ? displayName : [NSString stringWithFormat:@"Preset %ld", (long)index] }];
        }
    }
    [items sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"index"] compare:b[@"index"]];
    }];
    return items;
}

- (NSInteger)nextIndex {
    NSSet *used = [NSSet setWithArray:[[self presets] valueForKey:@"index"]];
    for (NSInteger i = 1; i <= DWMaxPresets; i++) if (![used containsObject:@(i)]) return i;
    return 0;
}

- (BOOL)copyFile:(NSString *)src to:(NSString *)dst error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:src]) {
        if (error) *error = [NSError errorWithDomain:@"DepthWallpaperPreset" code:1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Thiếu file: %@", src.lastPathComponent]}];
        return NO;
    }
    [fm removeItemAtPath:dst error:nil];
    return [fm copyItemAtPath:src toPath:dst error:error];
}

- (BOOL)saveCurrentAsPreset:(NSString *)name error:(NSError **)error {
    NSInteger index = [self nextIndex];
    if (index == 0) {
        if (error) *error = [NSError errorWithDomain:@"DepthWallpaperPreset" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Đã đạt tối đa 20 preset."}];
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = [[self directory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%02ld", (long)index]];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:error];
    if (error && *error) return NO;
    if (![self copyFile:DWWallpaperImagePath to:[dir stringByAppendingPathComponent:@"wallpaper.png"] error:error]) return NO;
    if (![self copyFile:DWCutoutImagePath to:[dir stringByAppendingPathComponent:@"cutout.png"] error:error]) return NO;
    NSDictionary *current = [NSDictionary dictionaryWithContentsOfFile:DWMetadataPath] ?: @{};
    NSMutableDictionary *meta = [current mutableCopy];
    meta[@"PresetName"] = name.length ? name : [NSString stringWithFormat:@"Preset %ld", (long)index];
    meta[@"SavedAt"] = @([[NSDate date] timeIntervalSince1970]);
    if (![meta writeToFile:[dir stringByAppendingPathComponent:@"meta.plist"] atomically:YES]) {
        if (error) *error = [NSError errorWithDomain:@"DepthWallpaperPreset" code:3 userInfo:@{NSLocalizedDescriptionKey:@"Không lưu được metadata preset."}];
        return NO;
    }
    return YES;
}

- (BOOL)loadPreset:(NSInteger)index error:(NSError **)error {
    if (index < 1 || index > DWMaxPresets) return NO;
    NSString *dir = [[self directory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%02ld", (long)index]];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:dir]) {
        if (error) *error = [NSError errorWithDomain:@"DepthWallpaperPreset" code:4 userInfo:@{NSLocalizedDescriptionKey:@"Preset không tồn tại."}];
        return NO;
    }
    NSString *wall = [dir stringByAppendingPathComponent:@"wallpaper.png"];
    NSString *cut = [dir stringByAppendingPathComponent:@"cutout.png"];
    NSString *meta = [dir stringByAppendingPathComponent:@"meta.plist"];
    if (![self copyFile:wall to:DWWallpaperImagePath error:error]) return NO;
    if (![self copyFile:cut to:DWCutoutImagePath error:error]) return NO;
    if (![self copyFile:meta to:DWMetadataPath error:error]) return NO;
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), DWReloadNotification, NULL, NULL, YES);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DepthWallpaperPresetDidLoad" object:nil];
    return YES;
}

- (BOOL)deletePreset:(NSInteger)index error:(NSError **)error {
    if (index < 1 || index > DWMaxPresets) return NO;
    NSString *dir = [[self directory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%02ld", (long)index]];
    if (![NSFileManager.defaultManager fileExistsAtPath:dir]) return YES;
    return [NSFileManager.defaultManager removeItemAtPath:dir error:error];
}

- (NSInteger)count { return self.presets.count; }

@end
