#import "BatteryClient.h"
#import <IOKit/IOKitLib.h>

@implementation BatteryClient

+ (NSDictionary<NSString *, id> *)getBatterySnapshot {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"));
    if (service == IO_OBJECT_NULL) {
        return nil;
    }

    CFMutableDictionaryRef props = NULL;
    kern_return_t result = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0);
    IOObjectRelease(service);

    if (result != kIOReturnSuccess || !props) {
        return nil;
    }

    return (__bridge_transfer NSDictionary<NSString *, id> *)props;
}

+ (id)valueAtPath:(NSArray<NSString *> *)path inSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    id current = snapshot;
    for (NSString *key in path) {
        if ([current isKindOfClass:[NSDictionary class]]) {
            current = ((NSDictionary *)current)[key];
        } else {
            return nil;
        }
    }
    return current;
}

+ (NSNumber *)numberAtPath:(NSArray<NSString *> *)path inSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    id value = [self valueAtPath:path inSnapshot:snapshot];
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

+ (NSString *)stringAtPath:(NSArray<NSString *> *)path inSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    id value = [self valueAtPath:path inSnapshot:snapshot];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

+ (NSArray *)arrayAtPath:(NSArray<NSString *> *)path inSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    id value = [self valueAtPath:path inSnapshot:snapshot];
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

+ (NSDictionary<NSString *, id> *)getBatteryInfo {
    NSDictionary<NSString *, id> *snapshot = [self getBatterySnapshot];
    if (!snapshot) {
        return @{
            @"present": @NO,
            @"source": @"IOKit",
            @"note": @"No battery found"
        };
    }
    return [self parseBatteryInfoFromSnapshot:snapshot];
}

+ (NSDictionary<NSString *, id> *)parseBatteryInfoFromSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary dictionary];
    info[@"present"] = @YES;
    info[@"source"] = @"IOKit";

    BOOL externalConnected = [[self numberAtPath:@[@"ExternalConnected"] inSnapshot:snapshot] boolValue];
    BOOL isCharging = [[self numberAtPath:@[@"IsCharging"] inSnapshot:snapshot] boolValue];
    info[@"externalConnected"] = @(externalConnected);
    info[@"isCharging"] = @(isCharging);
    info[@"status"] = externalConnected ? @"AC" : @"Battery";

    // Capacities (mAh)
    NSNumber *designCapacity = [self numberAtPath:@[@"DesignCapacity"] inSnapshot:snapshot];
    NSNumber *maxCapacity = [self numberAtPath:@[@"AppleRawMaxCapacity"] inSnapshot:snapshot];
    NSNumber *currentCapacity = [self numberAtPath:@[@"AppleRawCurrentCapacity"] inSnapshot:snapshot];
    NSNumber *nominalCapacity = [self numberAtPath:@[@"NominalChargeCapacity"] inSnapshot:snapshot];

    if (designCapacity) info[@"designCapacity"] = designCapacity;
    if (maxCapacity) info[@"maxCapacity"] = maxCapacity;
    if (currentCapacity) info[@"currentCapacity"] = currentCapacity;
    if (nominalCapacity) info[@"nominalChargeCapacity"] = nominalCapacity;

    if (maxCapacity && designCapacity && [designCapacity doubleValue] > 0) {
        double health = ([maxCapacity doubleValue] / [designCapacity doubleValue]) * 100.0;
        info[@"healthPercent"] = @(health);
    }

    // Voltages / currents
    NSNumber *voltage = [self numberAtPath:@[@"Voltage"] inSnapshot:snapshot];
    NSNumber *amperage = [self numberAtPath:@[@"Amperage"] inSnapshot:snapshot];
    NSNumber *instantAmperage = [self numberAtPath:@[@"InstantAmperage"] inSnapshot:snapshot];

    if (voltage) info[@"voltage"] = voltage;
    if (amperage) info[@"amperage"] = amperage;
    if (instantAmperage) info[@"instantAmperage"] = instantAmperage;

    // Watt-hours (mV * mAh / 1e6)
    if (voltage && designCapacity) {
        info[@"designWh"] = @([voltage doubleValue] * [designCapacity doubleValue] / 1000000.0);
    }
    if (voltage && currentCapacity) {
        info[@"currentWh"] = @([voltage doubleValue] * [currentCapacity doubleValue] / 1000000.0);
    }

    // Temperatures (reported in hundredths of a degree Celsius)
    NSNumber *temperature = [self numberAtPath:@[@"Temperature"] inSnapshot:snapshot];
    NSNumber *virtualTemp = [self numberAtPath:@[@"VirtualTemperature"] inSnapshot:snapshot];
    if (temperature) {
        info[@"temperature"] = @([temperature doubleValue] / 100.0);
        info[@"temperatureUnit"] = @"°C";
    }
    if (virtualTemp) {
        info[@"virtualTemperature"] = @([virtualTemp doubleValue] / 100.0);
    }

    // Cycle count
    NSNumber *cycleCount = [self numberAtPath:@[@"CycleCount"] inSnapshot:snapshot];
    if (cycleCount) info[@"cycleCount"] = cycleCount;

    // Time estimates (minutes)
    NSNumber *timeRemaining = [self numberAtPath:@[@"TimeRemaining"] inSnapshot:snapshot];
    NSNumber *avgTimeToEmpty = [self numberAtPath:@[@"AvgTimeToEmpty"] inSnapshot:snapshot];
    NSNumber *avgTimeToFull = [self numberAtPath:@[@"AvgTimeToFull"] inSnapshot:snapshot];
    if (timeRemaining) info[@"timeRemaining"] = timeRemaining;
    if (avgTimeToEmpty) info[@"avgTimeToEmpty"] = avgTimeToEmpty;
    if (avgTimeToFull) info[@"avgTimeToFull"] = avgTimeToFull;

    // Identification
    NSString *serial = [self stringAtPath:@[@"Serial"] inSnapshot:snapshot];
    NSString *deviceName = [self stringAtPath:@[@"DeviceName"] inSnapshot:snapshot];
    if (serial) info[@"serialNumber"] = serial;
    if (deviceName) info[@"deviceName"] = deviceName;

    // BatteryData: cell voltages, Qmax, manufacture date
    NSDictionary *batteryData = [self valueAtPath:@[@"BatteryData"] inSnapshot:snapshot];
    if ([batteryData isKindOfClass:[NSDictionary class]]) {
        NSArray *cellVoltages = batteryData[@"CellVoltage"];
        if ([cellVoltages isKindOfClass:[NSArray class]]) {
            NSMutableArray *volts = [NSMutableArray array];
            for (id v in cellVoltages) {
                if ([v isKindOfClass:[NSNumber class]]) {
                    [volts addObject:@([v doubleValue] / 1000.0)];
                }
            }
            info[@"cellVoltages"] = volts;
        }

        NSArray *qmax = batteryData[@"Qmax"];
        if ([qmax isKindOfClass:[NSArray class]]) {
            info[@"qmax"] = qmax;
        }

        NSNumber *mfgDate = batteryData[@"ManufactureDate"];
        if (mfgDate) info[@"manufactureDate"] = mfgDate;

        NSString *batterySerial = batteryData[@"Serial"];
        if (batterySerial) info[@"batterySerial"] = batterySerial;
    }

    // Adapter / input power
    NSDictionary *adapterDetails = [self valueAtPath:@[@"AdapterDetails"] inSnapshot:snapshot];
    if ([adapterDetails isKindOfClass:[NSDictionary class]]) {
        NSNumber *adapterWatts = adapterDetails[@"Watts"];
        NSNumber *adapterVoltage = adapterDetails[@"Voltage"];
        NSNumber *adapterCurrent = adapterDetails[@"Current"];
        NSString *adapterDesc = adapterDetails[@"Description"];
        NSMutableDictionary *adapter = [NSMutableDictionary dictionary];
        if (adapterWatts) adapter[@"watts"] = adapterWatts;
        if (adapterVoltage) adapter[@"voltage"] = adapterVoltage;
        if (adapterCurrent) adapter[@"current"] = adapterCurrent;
        if (adapterDesc) adapter[@"description"] = adapterDesc;
        if (adapter.count > 0) info[@"adapter"] = adapter;
        if (adapterWatts) info[@"inputPower"] = adapterWatts;
    }

    // Power telemetry (mW -> W)
    NSDictionary *powerTelemetry = [self valueAtPath:@[@"PowerTelemetryData"] inSnapshot:snapshot];
    if ([powerTelemetry isKindOfClass:[NSDictionary class]]) {
        NSNumber *systemPowerIn = powerTelemetry[@"SystemPowerIn"];
        NSNumber *batteryPower = powerTelemetry[@"BatteryPower"];
        NSNumber *systemVoltageIn = powerTelemetry[@"SystemVoltageIn"];
        NSNumber *systemCurrentIn = powerTelemetry[@"SystemCurrentIn"];
        if (systemPowerIn) info[@"systemPower"] = @([systemPowerIn doubleValue] / 1000.0);
        if (batteryPower) info[@"batteryPower"] = @([batteryPower doubleValue] / 1000.0);
        if (systemVoltageIn) info[@"systemVoltageIn"] = systemVoltageIn;
        if (systemCurrentIn) info[@"systemCurrentIn"] = systemCurrentIn;
    }

    // Charger data
    NSDictionary *chargerData = [self valueAtPath:@[@"ChargerData"] inSnapshot:snapshot];
    if ([chargerData isKindOfClass:[NSDictionary class]]) {
        NSNumber *chargingVoltage = chargerData[@"ChargingVoltage"];
        NSNumber *chargingCurrent = chargerData[@"ChargingCurrent"];
        if (chargingVoltage || chargingCurrent) {
            NSMutableDictionary *charger = [NSMutableDictionary dictionary];
            if (chargingVoltage) charger[@"voltage"] = chargingVoltage;
            if (chargingCurrent) charger[@"current"] = chargingCurrent;
            info[@"charger"] = charger;
        }
    }

    return info;
}

@end
