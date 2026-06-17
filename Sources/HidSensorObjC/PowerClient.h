#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PowerClient : NSObject

/// Returns a dictionary with a sensors array containing power readings from
/// AppleSmartBattery (IOKit). On a desktop with no battery it returns a note.
+ (NSDictionary<NSString *, id> *)getPowerInfo;

@end

NS_ASSUME_NONNULL_END
