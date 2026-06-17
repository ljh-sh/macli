#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HidSensorData : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) double value;
@property (nonatomic, copy) NSString *unit;
@end

@interface HidSensorClient : NSObject
+ (NSDictionary<NSString *, NSArray<HidSensorData *> *> *)getAll;
+ (NSArray<HidSensorData *> *)getTemperatures;
+ (NSArray<HidSensorData *> *)getVoltages;
+ (NSArray<HidSensorData *> *)getCurrents;
@end

NS_ASSUME_NONNULL_END
