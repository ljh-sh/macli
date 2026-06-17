#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BatteryClient : NSObject

/// Returns a dictionary of battery information from AppleSmartBattery (IOKit).
/// Keys include: present, source, status, cycleCount, designCapacity,
/// maxCapacity, currentCapacity, voltage, amperage, temperature, isCharging,
/// timeRemaining, healthPercent, note.
+ (NSDictionary<NSString *, id> *)getBatteryInfo;

@end

NS_ASSUME_NONNULL_END
