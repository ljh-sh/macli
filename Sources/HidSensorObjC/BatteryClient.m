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

+ (NSNumber *)asUnsigned:(NSNumber *)num {
    if (!num) return nil;
    return [NSNumber numberWithUnsignedLongLong:(uint64_t)[num longLongValue]];
}

+ (NSArray *)arrayAsUnsigned:(NSArray *)array {
    if (![array isKindOfClass:[NSArray class]]) return nil;
    NSMutableArray *out = [NSMutableArray array];
    for (id item in array) {
        if ([item isKindOfClass:[NSNumber class]]) {
            [out addObject:[self asUnsigned:item]];
        } else {
            [out addObject:item];
        }
    }
    return out;
}

+ (NSString *)hexStringFromData:(NSData *)data {
    if (!data || data.length == 0) return nil;
    const unsigned char *bytes = (const unsigned char *)data.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return hex;
}

/// Recursively convert IOKit values to JSON-friendly values.
/// NSData is dropped (opaque binary). Nested dictionaries/arrays are preserved.
+ (id)jsonFriendlyValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for (id item in value) {
            id converted = [self jsonFriendlyValue:item];
            if (converted) [out addObject:converted];
        }
        return out;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        for (NSString *key in value) {
            id converted = [self jsonFriendlyValue:value[key]];
            if (converted) out[key] = converted;
        }
        return out;
    }
    return nil;
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

    // MARK: - Status
    BOOL externalConnected = [[self numberAtPath:@[@"ExternalConnected"] inSnapshot:snapshot] boolValue];
    BOOL isCharging = [[self numberAtPath:@[@"IsCharging"] inSnapshot:snapshot] boolValue];
    info[@"externalConnected"] = @(externalConnected);
    info[@"isCharging"] = @(isCharging);
    info[@"status"] = externalConnected ? @"AC" : @"Battery";

    NSNumber *appleRawExternalConnected = [self numberAtPath:@[@"AppleRawExternalConnected"] inSnapshot:snapshot];
    if (appleRawExternalConnected) info[@"appleRawExternalConnected"] = appleRawExternalConnected;

    NSNumber *externalChargeCapable = [self numberAtPath:@[@"ExternalChargeCapable"] inSnapshot:snapshot];
    if (externalChargeCapable) info[@"externalChargeCapable"] = externalChargeCapable;

    NSNumber *fullyCharged = [self numberAtPath:@[@"FullyCharged"] inSnapshot:snapshot];
    if (fullyCharged) info[@"fullyCharged"] = fullyCharged;

    NSNumber *builtIn = [self numberAtPath:@[@"built-in"] inSnapshot:snapshot];
    if (builtIn) info[@"builtIn"] = builtIn;

    NSNumber *batteryInstalled = [self numberAtPath:@[@"BatteryInstalled"] inSnapshot:snapshot];
    if (batteryInstalled) info[@"batteryInstalled"] = batteryInstalled;

    NSNumber *batteryCellDisconnectCount = [self numberAtPath:@[@"BatteryCellDisconnectCount"] inSnapshot:snapshot];
    if (batteryCellDisconnectCount) info[@"batteryCellDisconnectCount"] = batteryCellDisconnectCount;

    NSNumber *atCriticalLevel = [self numberAtPath:@[@"AtCriticalLevel"] inSnapshot:snapshot];
    if (atCriticalLevel) info[@"atCriticalLevel"] = atCriticalLevel;

    NSNumber *permanentFailureStatus = [self numberAtPath:@[@"PermanentFailureStatus"] inSnapshot:snapshot];
    if (permanentFailureStatus) info[@"permanentFailureStatus"] = permanentFailureStatus;

    NSNumber *designCycleCount = [self numberAtPath:@[@"DesignCycleCount9C"] inSnapshot:snapshot];
    if (designCycleCount) info[@"designCycleCount"] = designCycleCount;

    NSNumber *gasGaugeFirmwareVersion = [self numberAtPath:@[@"GasGaugeFirmwareVersion"] inSnapshot:snapshot];
    if (gasGaugeFirmwareVersion) info[@"gasGaugeFirmwareVersion"] = gasGaugeFirmwareVersion;

    NSNumber *postChargeWaitSeconds = [self numberAtPath:@[@"PostChargeWaitSeconds"] inSnapshot:snapshot];
    if (postChargeWaitSeconds) info[@"postChargeWaitSeconds"] = postChargeWaitSeconds;

    NSNumber *postDischargeWaitSeconds = [self numberAtPath:@[@"PostDischargeWaitSeconds"] inSnapshot:snapshot];
    if (postDischargeWaitSeconds) info[@"postDischargeWaitSeconds"] = postDischargeWaitSeconds;

    NSNumber *batteryInvalidWakeSeconds = [self numberAtPath:@[@"BatteryInvalidWakeSeconds"] inSnapshot:snapshot];
    if (batteryInvalidWakeSeconds) info[@"batteryInvalidWakeSeconds"] = batteryInvalidWakeSeconds;

    NSNumber *updateTime = [self numberAtPath:@[@"UpdateTime"] inSnapshot:snapshot];
    if (updateTime) info[@"updateTime"] = updateTime;

    NSNumber *fullPathUpdated = [self numberAtPath:@[@"FullPathUpdated"] inSnapshot:snapshot];
    if (fullPathUpdated) info[@"fullPathUpdated"] = fullPathUpdated;

    NSNumber *bootPathUpdated = [self numberAtPath:@[@"BootPathUpdated"] inSnapshot:snapshot];
    if (bootPathUpdated) info[@"bootPathUpdated"] = bootPathUpdated;

    NSNumber *userVisiblePathUpdated = [self numberAtPath:@[@"UserVisiblePathUpdated"] inSnapshot:snapshot];
    if (userVisiblePathUpdated) info[@"userVisiblePathUpdated"] = userVisiblePathUpdated;

    NSNumber *location = [self numberAtPath:@[@"Location"] inSnapshot:snapshot];
    if (location) info[@"location"] = location;

    NSNumber *adapterInfo = [self numberAtPath:@[@"AdapterInfo"] inSnapshot:snapshot];
    if (adapterInfo) info[@"adapterInfo"] = adapterInfo;

    NSNumber *bestAdapterIndex = [self numberAtPath:@[@"BestAdapterIndex"] inSnapshot:snapshot];
    if (bestAdapterIndex) info[@"bestAdapterIndex"] = bestAdapterIndex;

    NSNumber *skipperNEIgnoreAtCritical = [self numberAtPath:@[@"SkipperNEIgnoreAtCritical"] inSnapshot:snapshot];
    if (skipperNEIgnoreAtCritical) info[@"skipperNEIgnoreAtCritical"] = skipperNEIgnoreAtCritical;

    NSNumber *maxCapacityPercent = [self numberAtPath:@[@"MaxCapacity"] inSnapshot:snapshot];
    if (maxCapacityPercent) info[@"maxCapacityPercent"] = maxCapacityPercent;

    NSNumber *chargerConfiguration = [self numberAtPath:@[@"ChargerConfiguration"] inSnapshot:snapshot];
    if (chargerConfiguration) info[@"chargerConfiguration"] = chargerConfiguration;

    NSDictionary *carrierMode = [self valueAtPath:@[@"CarrierMode"] inSnapshot:snapshot];
    if ([carrierMode isKindOfClass:[NSDictionary class]] && carrierMode.count > 0) {
        info[@"carrierMode"] = [self jsonFriendlyValue:carrierMode];
    }

    NSDictionary *deadBatteryBootData = [self valueAtPath:@[@"DeadBatteryBootData"] inSnapshot:snapshot];
    if ([deadBatteryBootData isKindOfClass:[NSDictionary class]] && deadBatteryBootData.count > 0) {
        info[@"deadBatteryBootData"] = [self jsonFriendlyValue:deadBatteryBootData];
    }

    NSDictionary *ocvData = [self valueAtPath:@[@"OCVData"] inSnapshot:snapshot];
    if ([ocvData isKindOfClass:[NSDictionary class]]) {
        info[@"ocvData"] = [self jsonFriendlyValue:ocvData];
    }

    NSDictionary *lpeMData = [self valueAtPath:@[@"LPEMData"] inSnapshot:snapshot];
    if ([lpeMData isKindOfClass:[NSDictionary class]]) {
        info[@"lpemData"] = [self jsonFriendlyValue:lpeMData];
    }

    // MARK: - Capacities (mAh)
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

    NSNumber *absoluteCapacity = [self numberAtPath:@[@"AbsoluteCapacity"] inSnapshot:snapshot];
    if (absoluteCapacity) info[@"absoluteCapacity"] = absoluteCapacity;

    NSNumber *packReserve = [self numberAtPath:@[@"PackReserve"] inSnapshot:snapshot];
    if (packReserve) info[@"packReserve"] = packReserve;

    // MARK: - Watt-hours
    NSNumber *voltage = [self numberAtPath:@[@"Voltage"] inSnapshot:snapshot];
    if (voltage && designCapacity) {
        info[@"designWh"] = @([voltage doubleValue] * [designCapacity doubleValue] / 1000000.0);
    }
    if (voltage && currentCapacity) {
        info[@"currentWh"] = @([voltage doubleValue] * [currentCapacity doubleValue] / 1000000.0);
    }

    // MARK: - Voltage / current
    if (voltage) info[@"voltage"] = voltage;

    NSNumber *amperage = [self numberAtPath:@[@"Amperage"] inSnapshot:snapshot];
    if (amperage) info[@"amperage"] = amperage;

    NSNumber *instantAmperage = [self numberAtPath:@[@"InstantAmperage"] inSnapshot:snapshot];
    if (instantAmperage) info[@"instantAmperage"] = instantAmperage;

    NSNumber *appleRawBatteryVoltage = [self numberAtPath:@[@"AppleRawBatteryVoltage"] inSnapshot:snapshot];
    if (appleRawBatteryVoltage) info[@"appleRawBatteryVoltage"] = appleRawBatteryVoltage;

    NSNumber *bootVoltage = [self numberAtPath:@[@"BootVoltage"] inSnapshot:snapshot];
    if (bootVoltage) info[@"bootVoltage"] = bootVoltage;

    // MARK: - State of charge (%)
    NSNumber *stateOfCharge = [self numberAtPath:@[@"CurrentCapacity"] inSnapshot:snapshot];
    if (stateOfCharge) info[@"stateOfCharge"] = stateOfCharge;

    // MARK: - Temperatures (reported in hundredths of a degree Celsius)
    NSNumber *temperature = [self numberAtPath:@[@"Temperature"] inSnapshot:snapshot];
    NSNumber *virtualTemp = [self numberAtPath:@[@"VirtualTemperature"] inSnapshot:snapshot];
    if (temperature) {
        info[@"temperature"] = @([temperature doubleValue] / 100.0);
        info[@"temperatureUnit"] = @"°C";
    }
    if (virtualTemp) {
        info[@"virtualTemperature"] = @([virtualTemp doubleValue] / 100.0);
    }

    // MARK: - Cycle count
    NSNumber *cycleCount = [self numberAtPath:@[@"CycleCount"] inSnapshot:snapshot];
    if (cycleCount) info[@"cycleCount"] = cycleCount;

    // MARK: - Time estimates (minutes)
    NSNumber *timeRemaining = [self numberAtPath:@[@"TimeRemaining"] inSnapshot:snapshot];
    NSNumber *avgTimeToEmpty = [self numberAtPath:@[@"AvgTimeToEmpty"] inSnapshot:snapshot];
    NSNumber *avgTimeToFull = [self numberAtPath:@[@"AvgTimeToFull"] inSnapshot:snapshot];
    if (timeRemaining) info[@"timeRemaining"] = timeRemaining;
    if (avgTimeToEmpty) info[@"avgTimeToEmpty"] = avgTimeToEmpty;
    if (avgTimeToFull) info[@"avgTimeToFull"] = avgTimeToFull;

    // MARK: - Identification
    NSString *serial = [self stringAtPath:@[@"Serial"] inSnapshot:snapshot];
    NSString *deviceName = [self stringAtPath:@[@"DeviceName"] inSnapshot:snapshot];
    if (serial) info[@"serialNumber"] = serial;
    if (deviceName) info[@"deviceName"] = deviceName;

    NSData *manufacturerData = [self valueAtPath:@[@"ManufacturerData"] inSnapshot:snapshot];
    if ([manufacturerData isKindOfClass:[NSData class]]) {
        NSString *hex = [self hexStringFromData:manufacturerData];
        if (hex) info[@"manufacturerData"] = hex;
    }

    // MARK: - BatteryData
    NSDictionary *batteryData = [self valueAtPath:@[@"BatteryData"] inSnapshot:snapshot];
    if ([batteryData isKindOfClass:[NSDictionary class]]) {
        // Already-exposed fields kept at top level for compatibility:
        // cellVoltages, qmax, manufactureDate, batterySerial.

        NSNumber *gaugeStateOfCharge = [self numberAtPath:@[@"StateOfCharge"] inSnapshot:batteryData];
        if (gaugeStateOfCharge) info[@"gaugeStateOfCharge"] = gaugeStateOfCharge;

        NSNumber *trueRemainingCapacity = [self numberAtPath:@[@"TrueRemainingCapacity"] inSnapshot:batteryData];
        if (trueRemainingCapacity) info[@"trueRemainingCapacity"] = trueRemainingCapacity;

        NSNumber *dailyMinSoc = [self numberAtPath:@[@"DailyMinSoc"] inSnapshot:batteryData];
        if (dailyMinSoc) info[@"dailyMinSoc"] = dailyMinSoc;

        NSNumber *dailyMaxSoc = [self numberAtPath:@[@"DailyMaxSoc"] inSnapshot:batteryData];
        if (dailyMaxSoc) info[@"dailyMaxSoc"] = dailyMaxSoc;

        NSNumber *passedCharge = [self numberAtPath:@[@"PassedCharge"] inSnapshot:batteryData];
        if (passedCharge) info[@"passedCharge"] = [self asUnsigned:passedCharge];

        NSNumber *chargeAccum = [self numberAtPath:@[@"ChargeAccum"] inSnapshot:batteryData];
        if (chargeAccum) info[@"chargeAccum"] = chargeAccum;

        NSNumber *flags = [self numberAtPath:@[@"Flags"] inSnapshot:batteryData];
        if (flags) info[@"batteryDataFlags"] = flags;

        NSNumber *gaugeFlagRaw = [self numberAtPath:@[@"GaugeFlagRaw"] inSnapshot:batteryData];
        if (gaugeFlagRaw) info[@"gaugeFlagRaw"] = gaugeFlagRaw;

        NSNumber *miscStatus = [self numberAtPath:@[@"MiscStatus"] inSnapshot:batteryData];
        if (miscStatus) info[@"miscStatus"] = miscStatus;

        NSNumber *itMiscStatus = [self numberAtPath:@[@"ITMiscStatus"] inSnapshot:batteryData];
        if (itMiscStatus) info[@"itMiscStatus"] = itMiscStatus;

        NSNumber *chemID = [self numberAtPath:@[@"ChemID"] inSnapshot:batteryData];
        if (chemID) info[@"chemID"] = chemID;

        NSNumber *algoChemID = [self numberAtPath:@[@"AlgoChemID"] inSnapshot:batteryData];
        if (algoChemID) info[@"algoChemID"] = algoChemID;

        NSNumber *fccComp1 = [self numberAtPath:@[@"FccComp1"] inSnapshot:batteryData];
        if (fccComp1) info[@"fccComp1"] = fccComp1;

        NSNumber *fccComp2 = [self numberAtPath:@[@"FccComp2"] inSnapshot:batteryData];
        if (fccComp2) info[@"fccComp2"] = fccComp2;

        NSNumber *resScale = [self numberAtPath:@[@"ResScale"] inSnapshot:batteryData];
        if (resScale) info[@"resScale"] = resScale;

        NSNumber *rss = [self numberAtPath:@[@"RSS"] inSnapshot:batteryData];
        if (rss) info[@"rss"] = rss;

        NSNumber *iss = [self numberAtPath:@[@"ISS"] inSnapshot:batteryData];
        if (iss) info[@"iss"] = iss;

        NSNumber *qstart = [self numberAtPath:@[@"Qstart"] inSnapshot:batteryData];
        if (qstart) info[@"qstart"] = qstart;

        NSNumber *dataFlashWriteCount = [self numberAtPath:@[@"DataFlashWriteCount"] inSnapshot:batteryData];
        if (dataFlashWriteCount) info[@"dataFlashWriteCount"] = dataFlashWriteCount;

        NSNumber *batteryHealthMetric = [self numberAtPath:@[@"BatteryHealthMetric"] inSnapshot:batteryData];
        if (batteryHealthMetric) info[@"batteryHealthMetric"] = batteryHealthMetric;

        NSNumber *batteryRsenseOpenCount = [self numberAtPath:@[@"BatteryRsenseOpenCount"] inSnapshot:batteryData];
        if (batteryRsenseOpenCount) info[@"batteryRsenseOpenCount"] = batteryRsenseOpenCount;

        NSNumber *cellCurrentAccumulatorCount = [self numberAtPath:@[@"CellCurrentAccumulatorCount"] inSnapshot:batteryData];
        if (cellCurrentAccumulatorCount) info[@"cellCurrentAccumulatorCount"] = cellCurrentAccumulatorCount;

        NSNumber *currentSenseMonitorStatus = [self numberAtPath:@[@"CurrentSenseMonitorStatus"] inSnapshot:batteryData];
        if (currentSenseMonitorStatus) info[@"currentSenseMonitorStatus"] = currentSenseMonitorStatus;

        NSNumber *dod0AtQualifiedQmax = [self numberAtPath:@[@"Dod0AtQualifiedQmax"] inSnapshot:batteryData];
        if (dod0AtQualifiedQmax) info[@"dod0AtQualifiedQmax"] = dod0AtQualifiedQmax;

        for (int i = 0; i <= 14; i++) {
            NSString *raKey = [NSString stringWithFormat:@"Ra%02d", i];
            NSNumber *ra = [self numberAtPath:@[raKey] inSnapshot:batteryData];
            if (ra) info[[raKey lowercaseString]] = ra;
        }

        NSNumber *batteryDataSystemPower = [self numberAtPath:@[@"SystemPower"] inSnapshot:batteryData];
        if (batteryDataSystemPower) info[@"batteryDataSystemPower"] = batteryDataSystemPower;

        NSNumber *batteryDataAdapterPower = [self numberAtPath:@[@"AdapterPower"] inSnapshot:batteryData];
        if (batteryDataAdapterPower) info[@"batteryDataAdapterPower"] = batteryDataAdapterPower;

        NSNumber *chemicalWeightedRa = [self numberAtPath:@[@"ChemicalWeightedRa"] inSnapshot:batteryData];
        if (chemicalWeightedRa) info[@"chemicalWeightedRa"] = chemicalWeightedRa;

        NSNumber *pmuConfigured = [self numberAtPath:@[@"PMUConfigured"] inSnapshot:batteryData];
        if (pmuConfigured) info[@"pmuConfigured"] = pmuConfigured;

        NSNumber *soc1Voltage = [self numberAtPath:@[@"Soc1Voltage"] inSnapshot:batteryData];
        if (soc1Voltage) info[@"soc1Voltage"] = soc1Voltage;

        NSNumber *qmaxDisqualificationReason = [self numberAtPath:@[@"QmaxDisqualificationReason"] inSnapshot:batteryData];
        if (qmaxDisqualificationReason) info[@"qmaxDisqualificationReason"] = qmaxDisqualificationReason;

        NSNumber *simRate = [self numberAtPath:@[@"SimRate"] inSnapshot:batteryData];
        if (simRate) info[@"simRate"] = simRate;

        NSNumber *idealCRate = [self numberAtPath:@[@"IdealCRate"] inSnapshot:batteryData];
        if (idealCRate) info[@"idealCRate"] = idealCRate;

        NSNumber *packCurrentAccumulator = [self numberAtPath:@[@"PackCurrentAccumulator"] inSnapshot:batteryData];
        if (packCurrentAccumulator) info[@"packCurrentAccumulator"] = [self asUnsigned:packCurrentAccumulator];

        NSNumber *packCurrentAccumulatorCount = [self numberAtPath:@[@"PackCurrentAccumulatorCount"] inSnapshot:batteryData];
        if (packCurrentAccumulatorCount) info[@"packCurrentAccumulatorCount"] = packCurrentAccumulatorCount;

        NSNumber *filteredCurrent = [self numberAtPath:@[@"FilteredCurrent"] inSnapshot:batteryData];
        if (filteredCurrent) info[@"filteredCurrent"] = filteredCurrent;

        NSNumber *dateOfFirstUse = [self numberAtPath:@[@"DateOfFirstUse"] inSnapshot:batteryData];
        if (dateOfFirstUse) info[@"dateOfFirstUse"] = dateOfFirstUse;

        NSNumber *gaugeCycleCount = [self numberAtPath:@[@"CycleCount"] inSnapshot:batteryData];
        if (gaugeCycleCount) info[@"gaugeCycleCount"] = gaugeCycleCount;

        NSArray *cellWom = [self arrayAtPath:@[@"CellWom"] inSnapshot:batteryData];
        if (cellWom) info[@"cellWom"] = cellWom;

        NSArray *presentDOD = [self arrayAtPath:@[@"PresentDOD"] inSnapshot:batteryData];
        if (presentDOD) info[@"presentDOD"] = presentDOD;

        NSArray *dod0 = [self arrayAtPath:@[@"DOD0"] inSnapshot:batteryData];
        if (dod0) info[@"dod0"] = dod0;

        NSArray *weightedRa = [self arrayAtPath:@[@"WeightedRa"] inSnapshot:batteryData];
        if (weightedRa) info[@"weightedRa"] = weightedRa;

        NSArray *cellCurrentAccumulator = [self arrayAtPath:@[@"CellCurrentAccumulator"] inSnapshot:batteryData];
        if (cellCurrentAccumulator) info[@"cellCurrentAccumulator"] = [self arrayAsUnsigned:cellCurrentAccumulator];

        // Cell voltages (mV -> V)
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

        NSArray *qmax = [self arrayAtPath:@[@"Qmax"] inSnapshot:batteryData];
        if (qmax) info[@"qmax"] = qmax;

        NSNumber *mfgDate = [self numberAtPath:@[@"ManufactureDate"] inSnapshot:batteryData];
        if (mfgDate) info[@"manufactureDate"] = mfgDate;

        NSString *batterySerial = [self stringAtPath:@[@"Serial"] inSnapshot:batteryData];
        if (batterySerial) info[@"batterySerial"] = batterySerial;

        NSData *batteryState = [self valueAtPath:@[@"BatteryState"] inSnapshot:batteryData];
        if ([batteryState isKindOfClass:[NSData class]]) {
            NSString *hex = [self hexStringFromData:batteryState];
            if (hex) info[@"batteryState"] = hex;
        }

        NSData *mfgData = [self valueAtPath:@[@"MfgData"] inSnapshot:batteryData];
        if ([mfgData isKindOfClass:[NSData class]]) {
            NSString *hex = [self hexStringFromData:mfgData];
            if (hex) info[@"mfgData"] = hex;
        }

        // LifetimeData (skip opaque binary blobs)
        NSDictionary *lifetimeData = [self valueAtPath:@[@"LifetimeData"] inSnapshot:batteryData];
        if ([lifetimeData isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *lifetime = [NSMutableDictionary dictionary];
            NSNumber *ltUpdateTime = lifetimeData[@"UpdateTime"];
            if (ltUpdateTime) lifetime[@"updateTime"] = ltUpdateTime;
            NSNumber *resistanceUpdatedDisabledCount = lifetimeData[@"ResistanceUpdatedDisabledCount"];
            if (resistanceUpdatedDisabledCount) lifetime[@"resistanceUpdatedDisabledCount"] = resistanceUpdatedDisabledCount;
            NSNumber *cycleCountLastQmax = lifetimeData[@"CycleCountLastQmax"];
            if (cycleCountLastQmax) lifetime[@"cycleCountLastQmax"] = cycleCountLastQmax;
            NSNumber *temperatureSamples = lifetimeData[@"TemperatureSamples"];
            if (temperatureSamples) lifetime[@"temperatureSamples"] = temperatureSamples;
            NSNumber *totalOperatingTime = lifetimeData[@"TotalOperatingTime"];
            if (totalOperatingTime) lifetime[@"totalOperatingTime"] = totalOperatingTime;
            NSNumber *maximumDischargeCurrent = lifetimeData[@"MaximumDischargeCurrent"];
            if (maximumDischargeCurrent) lifetime[@"maximumDischargeCurrent"] = [self asUnsigned:maximumDischargeCurrent];
            NSNumber *minimumPackVoltage = lifetimeData[@"MinimumPackVoltage"];
            if (minimumPackVoltage) lifetime[@"minimumPackVoltage"] = minimumPackVoltage;
            NSNumber *maximumPackVoltage = lifetimeData[@"MaximumPackVoltage"];
            if (maximumPackVoltage) lifetime[@"maximumPackVoltage"] = maximumPackVoltage;
            NSNumber *maximumChargeCurrent = lifetimeData[@"MaximumChargeCurrent"];
            if (maximumChargeCurrent) lifetime[@"maximumChargeCurrent"] = maximumChargeCurrent;
            NSNumber *averageTemperature = lifetimeData[@"AverageTemperature"];
            if (averageTemperature) lifetime[@"averageTemperature"] = averageTemperature;
            NSNumber *minimumTemperature = lifetimeData[@"MinimumTemperature"];
            if (minimumTemperature) lifetime[@"minimumTemperature"] = minimumTemperature;
            NSNumber *maximumTemperature = lifetimeData[@"MaximumTemperature"];
            if (maximumTemperature) lifetime[@"maximumTemperature"] = maximumTemperature;
            NSNumber *rdisCnt = lifetimeData[@"RDISCnt"];
            if (rdisCnt) lifetime[@"rdisCnt"] = rdisCnt;
            if (lifetime.count > 0) info[@"lifetimeData"] = lifetime;
        }
    }

    // MARK: - Adapter details
    NSDictionary *adapterDetails = [self valueAtPath:@[@"AdapterDetails"] inSnapshot:snapshot];
    if ([adapterDetails isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *adapter = [NSMutableDictionary dictionary];
        NSNumber *adapterWatts = adapterDetails[@"Watts"];
        NSNumber *adapterVoltage = adapterDetails[@"Voltage"];
        NSNumber *adapterAdapterVoltage = adapterDetails[@"AdapterVoltage"];
        NSNumber *adapterCurrent = adapterDetails[@"Current"];
        NSString *adapterDesc = adapterDetails[@"Description"];
        NSNumber *isWireless = adapterDetails[@"IsWireless"];
        NSNumber *adapterID = adapterDetails[@"AdapterID"];
        NSNumber *familyCode = adapterDetails[@"FamilyCode"];
        NSNumber *adapterPowerTier = adapterDetails[@"AdapterPowerTier"];
        NSNumber *usbHvcHvcIndex = adapterDetails[@"UsbHvcHvcIndex"];
        NSNumber *pmuConfiguration = adapterDetails[@"PMUConfiguration"];
        NSArray *usbHvcMenu = adapterDetails[@"UsbHvcMenu"];
        NSNumber *adapterSerialNumber = adapterDetails[@"SerialNumber"];

        if (adapterWatts) adapter[@"watts"] = adapterWatts;
        if (adapterVoltage) adapter[@"voltage"] = adapterVoltage;
        if (adapterAdapterVoltage) adapter[@"adapterVoltage"] = adapterAdapterVoltage;
        if (adapterCurrent) adapter[@"current"] = adapterCurrent;
        if (adapterDesc) adapter[@"description"] = adapterDesc;
        if (isWireless) adapter[@"isWireless"] = isWireless;
        if (adapterID) adapter[@"adapterID"] = adapterID;
        if (familyCode) adapter[@"familyCode"] = familyCode;
        if (adapterPowerTier) adapter[@"adapterPowerTier"] = adapterPowerTier;
        if (usbHvcHvcIndex) adapter[@"usbHvcHvcIndex"] = usbHvcHvcIndex;
        if (pmuConfiguration) adapter[@"pmuConfiguration"] = pmuConfiguration;
        if (usbHvcMenu) adapter[@"usbHvcMenu"] = [self jsonFriendlyValue:usbHvcMenu];
        if (adapterSerialNumber) adapter[@"serialNumber"] = adapterSerialNumber;

        if (adapter.count > 0) info[@"adapter"] = adapter;
        if (adapterWatts) info[@"inputPower"] = adapterWatts;
    }

    // AppleRawAdapterDetails: per-port raw adapter telemetry
    NSArray *appleRawAdapterDetails = [self valueAtPath:@[@"AppleRawAdapterDetails"] inSnapshot:snapshot];
    if ([appleRawAdapterDetails isKindOfClass:[NSArray class]]) {
        id converted = [self jsonFriendlyValue:appleRawAdapterDetails];
        if (converted) info[@"rawAdapterDetails"] = converted;
    }

    // MARK: - Power telemetry (mW -> W where applicable)
    NSDictionary *powerTelemetry = [self valueAtPath:@[@"PowerTelemetryData"] inSnapshot:snapshot];
    if ([powerTelemetry isKindOfClass:[NSDictionary class]]) {
        NSNumber *systemPowerIn = powerTelemetry[@"SystemPowerIn"];
        if (systemPowerIn) info[@"systemPower"] = @([systemPowerIn doubleValue] / 1000.0);

        NSNumber *batteryPower = powerTelemetry[@"BatteryPower"];
        if (batteryPower) info[@"batteryPower"] = @([batteryPower doubleValue] / 1000.0);

        NSNumber *systemVoltageIn = powerTelemetry[@"SystemVoltageIn"];
        if (systemVoltageIn) info[@"systemVoltageIn"] = systemVoltageIn;

        NSNumber *systemCurrentIn = powerTelemetry[@"SystemCurrentIn"];
        if (systemCurrentIn) info[@"systemCurrentIn"] = systemCurrentIn;

        NSNumber *systemLoad = powerTelemetry[@"SystemLoad"];
        if (systemLoad) info[@"systemLoad"] = systemLoad;

        NSNumber *wallEnergyEstimate = powerTelemetry[@"WallEnergyEstimate"];
        if (wallEnergyEstimate) info[@"wallEnergyEstimate"] = wallEnergyEstimate;

        NSNumber *systemEnergyConsumed = powerTelemetry[@"SystemEnergyConsumed"];
        if (systemEnergyConsumed) info[@"systemEnergyConsumed"] = systemEnergyConsumed;

        NSNumber *accumulatedSystemLoad = powerTelemetry[@"AccumulatedSystemLoad"];
        if (accumulatedSystemLoad) info[@"accumulatedSystemLoad"] = accumulatedSystemLoad;

        NSNumber *accumulatedSystemEnergyConsumed = powerTelemetry[@"AccumulatedSystemEnergyConsumed"];
        if (accumulatedSystemEnergyConsumed) info[@"accumulatedSystemEnergyConsumed"] = accumulatedSystemEnergyConsumed;

        NSNumber *accumulatedWallEnergyEstimate = powerTelemetry[@"AccumulatedWallEnergyEstimate"];
        if (accumulatedWallEnergyEstimate) info[@"accumulatedWallEnergyEstimate"] = accumulatedWallEnergyEstimate;

        NSNumber *accumulatedBatteryPower = powerTelemetry[@"AccumulatedBatteryPower"];
        if (accumulatedBatteryPower) info[@"accumulatedBatteryPower"] = accumulatedBatteryPower;

        NSNumber *accumulatedSystemPowerIn = powerTelemetry[@"AccumulatedSystemPowerIn"];
        if (accumulatedSystemPowerIn) info[@"accumulatedSystemPowerIn"] = accumulatedSystemPowerIn;

        NSNumber *accumulatedBatteryDischarge = powerTelemetry[@"AccumulatedBatteryDischarge"];
        if (accumulatedBatteryDischarge) info[@"accumulatedBatteryDischarge"] = [self asUnsigned:accumulatedBatteryDischarge];

        NSNumber *adapterEfficiencyLoss = powerTelemetry[@"AdapterEfficiencyLoss"];
        if (adapterEfficiencyLoss) info[@"adapterEfficiencyLoss"] = adapterEfficiencyLoss;

        NSNumber *accumulatedAdapterEfficiencyLoss = powerTelemetry[@"AccumulatedAdapterEfficiencyLoss"];
        if (accumulatedAdapterEfficiencyLoss) info[@"accumulatedAdapterEfficiencyLoss"] = [self asUnsigned:accumulatedAdapterEfficiencyLoss];

        NSNumber *powerTelemetryErrorCount = powerTelemetry[@"PowerTelemetryErrorCount"];
        if (powerTelemetryErrorCount) info[@"powerTelemetryErrorCount"] = powerTelemetryErrorCount;

        NSNumber *systemPowerInAccumulatorCount = powerTelemetry[@"SystemPowerInAccumulatorCount"];
        if (systemPowerInAccumulatorCount) info[@"systemPowerInAccumulatorCount"] = systemPowerInAccumulatorCount;

        NSNumber *systemLoadAccumulatorCount = powerTelemetry[@"SystemLoadAccumulatorCount"];
        if (systemLoadAccumulatorCount) info[@"systemLoadAccumulatorCount"] = systemLoadAccumulatorCount;

        NSNumber *adapterEfficiencyLossAccumulatorCount = powerTelemetry[@"AdapterEfficiencyLossAccumulatorCount"];
        if (adapterEfficiencyLossAccumulatorCount) info[@"adapterEfficiencyLossAccumulatorCount"] = adapterEfficiencyLossAccumulatorCount;

        NSNumber *batteryPowerAccumulatorCount = powerTelemetry[@"BatteryPowerAccumulatorCount"];
        if (batteryPowerAccumulatorCount) info[@"batteryPowerAccumulatorCount"] = batteryPowerAccumulatorCount;

        NSNumber *batteryDischargeAccumulatorCount = powerTelemetry[@"BatteryDischargeAccumulatorCount"];
        if (batteryDischargeAccumulatorCount) info[@"batteryDischargeAccumulatorCount"] = batteryDischargeAccumulatorCount;
    }

    // MARK: - Charger data
    NSDictionary *chargerData = [self valueAtPath:@[@"ChargerData"] inSnapshot:snapshot];
    if ([chargerData isKindOfClass:[NSDictionary class]]) {
        NSNumber *chargingVoltage = chargerData[@"ChargingVoltage"];
        NSNumber *chargingCurrent = chargerData[@"ChargingCurrent"];
        NSMutableDictionary *charger = [NSMutableDictionary dictionary];
        if (chargingVoltage) charger[@"voltage"] = chargingVoltage;
        if (chargingCurrent) charger[@"current"] = chargingCurrent;

        NSData *chargerStatus = chargerData[@"ChargerStatus"];
        if ([chargerStatus isKindOfClass:[NSData class]]) {
            NSString *hex = [self hexStringFromData:chargerStatus];
            if (hex) charger[@"status"] = hex;
        }

        NSNumber *vacVoltageLimit = chargerData[@"VacVoltageLimit"];
        if (vacVoltageLimit) charger[@"vacVoltageLimit"] = vacVoltageLimit;

        NSNumber *notChargingReason = chargerData[@"NotChargingReason"];
        if (notChargingReason) charger[@"notChargingReason"] = notChargingReason;

        NSNumber *slowChargingReason = chargerData[@"SlowChargingReason"];
        if (slowChargingReason) charger[@"slowChargingReason"] = slowChargingReason;

        NSNumber *chargerResetCounter = chargerData[@"ChargerResetCounter"];
        if (chargerResetCounter) charger[@"resetCounter"] = chargerResetCounter;

        NSNumber *chargerID = chargerData[@"ChargerID"];
        if (chargerID) charger[@"chargerID"] = chargerID;

        NSNumber *timeChargingThermallyLimited = chargerData[@"TimeChargingThermallyLimited"];
        if (timeChargingThermallyLimited) charger[@"timeChargingThermallyLimited"] = timeChargingThermallyLimited;

        NSNumber *chargerInhibitReason = chargerData[@"ChargerInhibitReason"];
        if (chargerInhibitReason) charger[@"inhibitReason"] = chargerInhibitReason;

        if (charger.count > 0) info[@"charger"] = charger;
    }

    // MARK: - FedDetails (USB-C PD partner info)
    NSArray *fedDetails = [self valueAtPath:@[@"FedDetails"] inSnapshot:snapshot];
    if ([fedDetails isKindOfClass:[NSArray class]]) {
        id converted = [self jsonFriendlyValue:fedDetails];
        if (converted) info[@"fedDetails"] = converted;
    }

    // MARK: - PortControllerInfo (per-port PD controller diagnostics)
    NSArray *portControllerInfo = [self valueAtPath:@[@"PortControllerInfo"] inSnapshot:snapshot];
    if ([portControllerInfo isKindOfClass:[NSArray class]]) {
        id converted = [self jsonFriendlyValue:portControllerInfo];
        if (converted) info[@"portControllerInfo"] = converted;
    }

    return info;
}

@end
