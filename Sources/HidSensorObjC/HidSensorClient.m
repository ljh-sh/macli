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

+ (NSArray<HidSensorData *> *)getTemperatures {
    return [self getSensorsWithUsagePage:0xff00 usage:5 eventType:kIOHIDEventTypeTemperature unit:@"°C" divisor:1.0];
}

+ (NSArray<HidSensorData *> *)getVoltages {
    return [self getSensorsWithUsagePage:0xff08 usage:3 eventType:kIOHIDEventTypePower unit:@"V" divisor:1000.0];
}

+ (NSArray<HidSensorData *> *)getCurrents {
    return [self getSensorsWithUsagePage:0xff08 usage:2 eventType:kIOHIDEventTypePower unit:@"A" divisor:1000.0];
}

+ (NSArray<HidSensorData *> *)getSensorsWithUsagePage:(int)page usage:(int)usage eventType:(int64_t)eventType unit:(NSString *)unit divisor:(double)divisor {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return @[];
    
    NSDictionary *match = @{
        @"PrimaryUsagePage": @(page),
        @"PrimaryUsage": @(usage)
    };
    IOHIDEventSystemClientSetMatching(client, (__bridge CFDictionaryRef)match);
    
    CFArrayRef servicesCF = IOHIDEventSystemClientCopyServices(client);
    if (!servicesCF) {
        CFRelease(client);
        return @[];
    }
    NSArray *services = (__bridge_transfer NSArray *)servicesCF;
    
    NSMutableArray<HidSensorData *> *result = [NSMutableArray array];
    
    for (id serviceObj in services) {
        IOHIDServiceClientRef service = (__bridge IOHIDServiceClientRef)serviceObj;
        
        NSString *name = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(service, (__bridge CFStringRef)@"Product");
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, eventType, 0, 0);
        
        if (event) {
            double value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(eventType));
            
            if (value != 0 && value > -127 && value < 10000) {
                HidSensorData *sensor = [[HidSensorData alloc] init];
                sensor.name = name ?: @"Unknown";
                sensor.value = value / divisor;
                sensor.unit = unit;
                [result addObject:sensor];
            }
            CFRelease(event);
        }
    }
    
    CFRelease(client);
    return result;
}

@end
