#import "PowerClient.h"
#import <IOKit/IOKitLib.h>

@implementation PowerClient

+ (NSNumber *)numberFromService:(io_service_t)service key:(NSString *)key {
    CFNumberRef ref = IORegistryEntryCreateCFProperty(service, (__bridge CFStringRef)key, kCFAllocatorDefault, 0);
    if (!ref) return nil;
    return (__bridge_transfer NSNumber *)ref;
}

+ (void)addAdapterPower:(id)adapterDetails to:(NSMutableArray<NSDictionary<NSString *, id> *> *)sensors {
    NSDictionary *dict = nil;
    if ([adapterDetails isKindOfClass:[NSArray class]] && [adapterDetails count] > 0) {
        dict = adapterDetails[0];
    } else if ([adapterDetails isKindOfClass:[NSDictionary class]]) {
        dict = adapterDetails;
    }
    NSNumber *watts = dict[@"Watts"];
    if (watts) {
        [sensors addObject:@{
            @"name": @"AC Adapter Power",
            @"value": watts,
            @"unit": @"W"
        }];
    }
}

+ (NSDictionary<NSString *, id> *)getPowerInfo {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"));
    if (service == IO_OBJECT_NULL) {
        return @{
            @"ok": @YES,
            @"source": @"IOKit",
            @"sensors": @[],
            @"count": @0,
            @"note": @"No battery found; power readings unavailable"
        };
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *sensors = [NSMutableArray array];

    NSNumber *voltage = [self numberFromService:service key:@"Voltage"];
    NSNumber *amperage = [self numberFromService:service key:@"Amperage"];
    if (voltage && amperage) {
        double watts = [voltage doubleValue] * [amperage doubleValue] / 1000000.0;
        [sensors addObject:@{
            @"name": @"Battery Power",
            @"value": @(watts),
            @"unit": @"W"
        }];
    }

    CFTypeRef adapterDetailsRef = IORegistryEntryCreateCFProperty(service, (__bridge CFStringRef)@"AdapterDetails", kCFAllocatorDefault, 0);
    if (adapterDetailsRef) {
        id adapterDetails = (__bridge_transfer id)adapterDetailsRef;
        [self addAdapterPower:adapterDetails to:sensors];
    }

    IOObjectRelease(service);

    return @{
        @"ok": @YES,
        @"source": @"IOKit",
        @"sensors": sensors,
        @"count": @(sensors.count)
    };
}

@end
