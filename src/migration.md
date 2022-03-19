# To migrate stable data:

1. Add new DayData type

```
public type DayCanisterMemoryMaxLiveSizeData = [var Nat64];
public type DayData_v2 = { // specific day data with all necessary metrics
    updateCallsData: DayUpdateCallsCountData;                    
    canisterHeapMemorySizeData: DayCanisterHeapMemorySizeData;
    canisterMemorySizeData: DayCanisterMemorySizeData;
    canisterCyclesData: DayCanisterCyclesData;
    canisterMemoryMaxLiveSizeData: DayCanisterMemoryMaxLiveSizeData;
};
```

2. Change HashMap signature

```
private type DayDataMap = HashMap.HashMap<DayDataId, DayData_v2>;
```

3. Add new Upgrade data tuple

```
private type UpgradeDataDayTuple_v2 = (DayDataId, DayData_v2);
```

4. Add new variant to UpgradeData

```
public type UpgradeData = {
    #v1 : {dayData: [UpgradeDataDayTuple]};
    #v2 : {dayData: [UpgradeDataDayTuple_v2]};
};
```

5. Add new method for default upgrade data and use it

```
private func createDefaultUpgradeData_v2(): UpgradeData {
    return #v2 {
        dayData = []
    };
};

public func newCanisterMonitoringState(): CanisterMonitoringState {
    let defaultUpgradeData: UpgradeData = createDefaultUpgradeData_v2();
    return loadCanisterMonitoringState(?defaultUpgradeData);
};
```

6. Add new method to prepare upgrade data for preupgrade phase and use it

```
private func prepareCurrentUpgradeData_v2(state: CanisterMonitoringState): UpgradeData {
    let dayData : [UpgradeDataDayTuple_v2] = Iter.toArray<(DayDataId, DayData_v2)>(state.dayDataMap.entries());
    let upgradeData : UpgradeData = #v2 {
        dayData = dayData;
    };
    return upgradeData;
};

public func prepareUpgradeData(state: CanisterMonitoringState): UpgradeData {
    let upgradeData : UpgradeData = prepareCurrentUpgradeData_v2(state);
    return upgradeData;
};
```

7. Add migration logic to migrate from v1 to v2 in postupgrade phase

```
private func migrateUpgradeData(upgradeData: UpgradeData): UpgradeData {
    switch (upgradeData) {
        case (#v1 value) {
            let from_v1_to_v2: [UpgradeDataDayTuple_v2] = Array.map<UpgradeDataDayTuple,UpgradeDataDayTuple_v2>(
                value.dayData,
                func (dayDataId: DayDataId, dayData: DayData) { 
                    let numberOfIntervals = dayData.updateCallsData.size();
                    let dayData_v2: DayData_v2 = {
                        updateCallsData: DayUpdateCallsCountData = dayData.updateCallsData;                    
                        canisterHeapMemorySizeData: DayCanisterHeapMemorySizeData = dayData.canisterHeapMemorySizeData;
                        canisterMemorySizeData: DayCanisterMemorySizeData = dayData.canisterMemorySizeData;
                        canisterCyclesData: DayCanisterCyclesData = dayData.canisterCyclesData;
                        canisterMemoryMaxLiveSizeData: DayCanisterMemoryMaxLiveSizeData = Array.tabulateVar<Nat64>(numberOfIntervals, func(index: Nat) : Nat64 { 0 } );
                    };
                    return (dayDataId, dayData_v2);
                }
            );
            let migrationStepResult: UpgradeData = #v2 {dayData = from_v1_to_v2};
            return migrateUpgradeData(migrationStepResult);
        };
        case (#v2 value) {
            return upgradeData;
        };
    };
};
```

8. Add logic to create state from v2 upgrade data

```
private func createCanisterMonitoringStateFromMigratedUpgradeData(upgradeData: UpgradeData): CanisterMonitoringState {
    switch (upgradeData) {
        case (#v2 value) {
            let count = value.dayData.size();
            let dayDataIter: Iter.Iter<UpgradeDataDayTuple_v2> =  value.dayData.vals();
            let newDayDataMap: DayDataMap = HashMap.fromIter<DayDataId, DayData_v2>(dayDataIter, count * 2, dayDataIdKeyEq, dayDataIdKeyHash);
            return {
                dayDataMap = newDayDataMap
            };
        };
        case (_) {
            // UNSUPPORTED variant!
            return newCanisterMonitoringState();
        };
    };
};
```

9. Change collectMetrics logic based on new v2 types

```
/*
methods to change:
- collectMetrics
- obtainDayDataFromMap
- createNewDayDataValue
- new methods for new part of v2
*/
```