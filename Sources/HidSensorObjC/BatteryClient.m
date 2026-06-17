#import "BatteryClient.h"
#import <IOKit/IOKitLib.h>

@implementation BatteryClient

+ (NSNumber *)numberFromService:(io_service_t)service key:(NSString *)key {
    CFNumberRef ref = IORegistryEntryCreateCFProperty(service, (__bridge CFStringRef)key, kCFAllocatorDefault, 0);
    if (!ref) return nil;
    NSNumber *value = (__bridge_transfer NSNumber *)ref;
    return value;
}

+ (BOOL)boolFromService:(io_service_t)service key:(NSString *)key {
    CFBooleanRef ref = IORegistryEntryCreateCFProperty(service, (__bridge CFStringRef)key, kCFAllocatorDefault, 0);
    if (!ref) return NO;
    BOOL value = CFBooleanGetValue(ref);
    CFRelease(ref);
    return value;
}

+ (NSDictionary<NSString *, id> *)getBatteryInfo {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"));
    if (service == IO_OBJECT_NULL) {
        return @{
            @"present": @NO,
            @"source": @"IOKit",
            @"note": @"No battery found"
        };
    }

    NSNumber *cycleCount = [self numberFromService:service key:@"CycleCount"];
    NSNumber *designCapacity = [self numberFromService:service key:@"DesignCapacity"];
    NSNumber *maxCapacity = [self numberFromService:service key:@"AppleRawMaxCapacity"];
    NSNumber *currentCapacity = [self numberFromService:service key:@"AppleRawCurrentCapacity"];
    NSNumber *voltage = [self numberFromService:service key:@"Voltage"];
    NSNumber *amperage = [self numberFromService:service key:@"Amperage"];
    NSNumber *temperature = [self numberFromService:service key:@"Temperature"];
    NSNumber *timeRemaining = [self numberFromService:service key:@"TimeRemaining"];
    BOOL externalConnected = [self boolFromService:service key:@"ExternalConnected"];
    BOOL isCharging = [self boolFromService:service key:@"IsCharging"];

    IOObjectRelease(service);

    NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary dictionary];
    info[@"present"] = @YES;
    info[@"source"] = @"IOKit";
    info[@"status"] = externalConnected ? @"AC" : @"Battery";
    info[@"externalConnected"] = @(externalConnected);
    info[@"isCharging"] = @(isCharging);

    if (cycleCount) info[@"cycleCount"] = cycleCount;
    if (designCapacity) info[@"designCapacity"] = designCapacity;
    if (maxCapacity) info[@"maxCapacity"] = maxCapacity;
    if (currentCapacity) info[@"currentCapacity"] = currentCapacity;
    if (voltage) info[@"voltage"] = voltage;
    if (amperage) info[@"amperage"] = amperage;
    if (timeRemaining) info[@"timeRemaining"] = timeRemaining;

    if (temperature) {
        // Temperature is reported in hundredths of a degree Celsius (e.g. 3022 -> 30.22 °C).
        double celsius = [temperature doubleValue] / 100.0;
        info[@"temperature"] = @(celsius);
        info[@"temperatureUnit"] = @"°C";
    }

    if (maxCapacity && designCapacity && [designCapacity doubleValue] > 0) {
        double health = ([maxCapacity doubleValue] / [designCapacity doubleValue]) * 100.0;
        info[@"healthPercent"] = @(health);
    }

    return info;
}

@end
