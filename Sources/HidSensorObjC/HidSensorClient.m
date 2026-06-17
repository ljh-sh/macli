#import "HidSensorClient.h"
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef double IOHIDFloat;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t eventType, int32_t options, int64_t ts);
extern IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

@implementation HidSensorData
@end

@implementation HidSensorClient

#define IOHIDEventFieldBase(type) (type << 16)
#define kIOHIDEventTypeTemperature 15
#define kIOHIDEventTypePower 25

+ (NSDictionary<NSString *, NSArray<HidSensorData *> *> *)getAll {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return @{};

    NSDictionary<NSString *, NSArray<HidSensorData *> *> *result = @{
        @"currents": [self getSensorsWithClient:client page:0xff08 usage:2 eventType:kIOHIDEventTypePower unit:@"A" divisor:1000.0],
        @"voltages": [self getSensorsWithClient:client page:0xff08 usage:3 eventType:kIOHIDEventTypePower unit:@"V" divisor:1000.0],
        @"temperatures": [self getSensorsWithClient:client page:0xff00 usage:5 eventType:kIOHIDEventTypeTemperature unit:@"°C" divisor:1.0],
    };

    CFRelease(client);
    return result;
}

+ (NSArray<HidSensorData *> *)getTemperatures {
    return [self getAll][@"temperatures"] ?: @[];
}

+ (NSArray<HidSensorData *> *)getVoltages {
    return [self getAll][@"voltages"] ?: @[];
}

+ (NSArray<HidSensorData *> *)getCurrents {
    return [self getAll][@"currents"] ?: @[];
}

+ (NSArray<HidSensorData *> *)getSensorsWithClient:(IOHIDEventSystemClientRef)client
                                              page:(int)page
                                             usage:(int)usage
                                         eventType:(int64_t)eventType
                                              unit:(NSString *)unit
                                          divisor:(double)divisor {
    NSMutableArray<HidSensorData *> *result = [NSMutableArray array];
    if (!client) return result;

    NSDictionary *match = @{
        @"PrimaryUsagePage": @(page),
        @"PrimaryUsage": @(usage)
    };
    IOHIDEventSystemClientSetMatching(client, (__bridge CFDictionaryRef)match);

    CFArrayRef servicesCF = IOHIDEventSystemClientCopyServices(client);
    if (!servicesCF) return result;

    NSArray *services = (__bridge_transfer NSArray *)servicesCF;

    for (id serviceObj in services) {
        IOHIDServiceClientRef service = (__bridge IOHIDServiceClientRef)serviceObj;

        NSString *name = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(service, (__bridge CFStringRef)@"Product");
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, eventType, 0, 0);

        if (event) {
            double value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(eventType));

            BOOL include = NO;
            if (eventType == kIOHIDEventTypeTemperature) {
                include = (value > -127 && value < 10000);
            } else {
                include = (value > 0);
            }

            if (include) {
                HidSensorData *sensor = [[HidSensorData alloc] init];
                sensor.name = name ?: @"Unknown";
                sensor.value = value / divisor;
                sensor.unit = unit;
                [result addObject:sensor];
            }

            CFRelease(event);
        }
    }

    return result;
}

@end
