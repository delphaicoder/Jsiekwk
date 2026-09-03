#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWPresetManager : NSObject
+ (instancetype)sharedManager;
- (NSArray<NSDictionary *> *)presets;
- (BOOL)saveCurrentAsPreset:(NSString *)name error:(NSError **)error;
- (BOOL)loadPreset:(NSInteger)index error:(NSError **)error;
- (BOOL)deletePreset:(NSInteger)index error:(NSError **)error;
- (NSInteger)count;
@end

NS_ASSUME_NONNULL_END
