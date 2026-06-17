#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BatteryClient : NSObject

/// Returns the full raw AppleSmartBattery IORegistry snapshot, or nil if
/// no battery is present.
+ (nullable NSDictionary<NSString *, id> *)getBatterySnapshot;

/// Returns a normalized, script-friendly dictionary of battery information.
+ (NSDictionary<NSString *, id> *)getBatteryInfo;

/// Normalizes a raw AppleSmartBattery snapshot. Exposed for testing.
+ (NSDictionary<NSString *, id> *)parseBatteryInfoFromSnapshot:(NSDictionary<NSString *, id> *)snapshot;

@end

NS_ASSUME_NONNULL_END
