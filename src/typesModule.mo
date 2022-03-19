import Array "mo:base/Array";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Prim "mo:prim";

module {

    // DayData types

    public type DayUpdateCallsCountData = [var Nat64];          // number of update calls in each time interval for a specific day. E.g. array with 288 elements for 5-minute intervals.
    public type DayCanisterHeapMemorySizeData = [var Nat64];    // canister heap memory size in each time interval for a specific day. E.g. array with 288 elements for 5-minute intervals.
    public type DayCanisterMemorySizeData = [var Nat64];        // canister memory size in each time interval for a specific day. E.g. array with 288 elements for 5-minute intervals.
    public type DayCanisterCyclesData = [var Nat64];            // canister available cycles in each time interval for a specific day. E.g. array with 288 elements for 5-minute intervals.

    public type DayData = { // specific day data with all necessary metrics
        updateCallsData: DayUpdateCallsCountData;
        canisterHeapMemorySizeData: DayCanisterHeapMemorySizeData;
        canisterMemorySizeData: DayCanisterMemorySizeData;
        canisterCyclesData: DayCanisterCyclesData;
    };

    // DayData identifier

    public type DayDataId = Nat32;  // composite key of the day data: 8 bits - year, 4 bits - month, 8 bits - day
    private let dayDataIdKeyEq: (DayDataId, DayDataId) -> Bool = func(x, y) { x == y };
    private let dayDataIdKeyHash: (DayDataId) -> Hash.Hash = func(x) { Hash.hash(Nat32.toNat(x)) };

    private func dayDataIdToNat32(dayDataId: DayDataId) : Nat32 {
        return dayDataId;
    };

    private type DayDataMap = HashMap.HashMap<DayDataId, DayData>;

    private let MINIMAL_VALID_YEAR = 2000;

    public func toDayDataId(year: Nat, month: Nat, day: Nat) : ?DayDataId {
        do ? {
            /*
            8 bits - year
            4 bits - month
            8 bits - day
            */
            if (year >= MINIMAL_VALID_YEAR) {
                let yearIndex : Nat = year - MINIMAL_VALID_YEAR; //offset 2000 to reduce number of bits for year
                var dayDataId : Nat32 = (Nat32.fromNat(yearIndex) & 0x000000FF);
                dayDataId := (dayDataId << 4) | (Nat32.fromNat(month) & 0xF);
                dayDataId := (dayDataId << 8) | (Nat32.fromNat(day) & 0xFF);
                return ?dayDataId;
            };
            return null;
        };
    };

    private func fromDayDataIdToYear(dayDataId: DayDataId) : Nat {
        return Nat32.toNat((dayDataId >> 12) & 0x000000FF);
    };

    private func fromDayDataIdToMonth(dayDataId: DayDataId) : Nat {
        return Nat32.toNat((dayDataId >> 8) & 0x0000000F);
    };

    private func fromDayDataIdToDay(dayDataId: DayDataId) : Nat {
        return Nat32.toNat(dayDataId & 0x000000FF);
    };

    // State

    public type CanisterMonitoringState = {
        dayDataMap: DayDataMap
    };

    // Post/Pre upgrade types

    private type UpgradeDataDayTuple = (DayDataId, DayData);

    public type UpgradeData = {
        #v1 : {dayData: [UpgradeDataDayTuple]};
    };

    // Querying metrics types

    public type MetricsGranularity = {
        #hourly;
        #daily;
    };

    public type UpdateCallsAggregatedData = [Nat64];
    public type CanisterHeapMemoryAggregatedData = [Nat64];
    public type CanisterMemoryAggregatedData = [Nat64];
    public type CanisterCyclesAggregatedData = [Nat64];

    public type HourlyMetricsData = {
        timeMillis: Int;
        updateCalls: UpdateCallsAggregatedData;
        /*
            "heap_size" contains the actual size of the current Motoko heap.
        */
        canisterHeapMemorySize: CanisterHeapMemoryAggregatedData;
        /*
            "memory_size" is the current size of the Wasm memory array (mostly the same as the canister memory size).
            This can only grow, never shrink in Wasm, even if most of it is unused.
            However, unused/unmodified canister memory ought to have no cost on the IC.
        */
        canisterMemorySize: CanisterMemoryAggregatedData;
        canisterCycles: CanisterCyclesAggregatedData;
    };

    public type NumericEntity = {
        min: Nat64;
        max: Nat64;
        first: Nat64;
        last: Nat64;
        avg: Nat64
    };

    public type DailyMetricsData = {
        timeMillis: Int;
        updateCalls: Nat64;
        canisterHeapMemorySize: NumericEntity;
        canisterMemorySize: NumericEntity;
        canisterCycles: NumericEntity;
    };

    public type CanisterMetricsData = {
        #hourly: [HourlyMetricsData];
        #daily: [DailyMetricsData];
    };

    public type CanisterMetrics = {
        data: CanisterMetricsData;
    };

    // Init / Pre-Post Upgrade functions

    public func newCanisterMonitoringState(): CanisterMonitoringState {
        let defaultUpgradeData: UpgradeData = createDefaultUpgradeData_v1();
        return loadCanisterMonitoringState(?defaultUpgradeData);
    };

    public func loadCanisterMonitoringState(upgradeData: ?UpgradeData): CanisterMonitoringState {
        return switch(upgradeData) {
            case null { newCanisterMonitoringState(); };
            case (?upgradeDataValue) {
                let migratedUpgradeData: UpgradeData = migrateUpgradeData(upgradeDataValue);
                let state: CanisterMonitoringState = createCanisterMonitoringStateFromMigratedUpgradeData(migratedUpgradeData);
                return state;
            };
        };
    };

    public func prepareUpgradeData(state: CanisterMonitoringState): UpgradeData {
        let upgradeData : UpgradeData = prepareCurrentUpgradeData_v1(state);
        return upgradeData;
    };

    // Stable data migration

    private func createDefaultUpgradeData_v1(): UpgradeData {
        return #v1 {
            dayData = []
        };
    };

    private func prepareCurrentUpgradeData_v1(state: CanisterMonitoringState): UpgradeData {
        let dayData : [UpgradeDataDayTuple] = Iter.toArray<(DayDataId, DayData)>(state.dayDataMap.entries());
        let upgradeData : UpgradeData = #v1 {
            dayData = dayData;
        };
        return upgradeData;
    };

    private func migrateUpgradeData(upgradeData: UpgradeData): UpgradeData {
        switch (upgradeData) {
            case (#v1 value) {
                return upgradeData
            };
        };
    };

    private func createCanisterMonitoringStateFromMigratedUpgradeData(upgradeData: UpgradeData): CanisterMonitoringState {
        switch (upgradeData) {
            case (#v1 value) {
                let count = value.dayData.size();
                let dayDataIter: Iter.Iter<UpgradeDataDayTuple> =  value.dayData.vals();
                let newDayDataMap: DayDataMap = HashMap.fromIter<DayDataId, DayData>(dayDataIter, count * 2, dayDataIdKeyEq, dayDataIdKeyHash);
                return {
                    dayDataMap = newDayDataMap
                };
            };
        };
    };

    // New metrics calculating functions

    public func collectMetrics(state: CanisterMonitoringState, dayDataId: DayDataId, intervalIndex: Nat, granularitySeconds: Nat) {
        ignore do ? {
            //obtain day data (create new one if does not exist)
            let dayData_v1: DayData = obtainDayDataFromMap(state, dayDataId, granularitySeconds);
            //bump number of update calls
            let newNumberOfUpdateCalls: Nat64 = tryToBumpUpdateCalls(dayData_v1.updateCallsData, intervalIndex)!;
            //analyze if we need to collect additional info
            let shouldCollectAdditionalInfo = shouldCollectHeapMemoryAndCycles(newNumberOfUpdateCalls);
            if (shouldCollectAdditionalInfo) {
                collectHeapMemory(dayData_v1.canisterHeapMemorySizeData, intervalIndex);
                collectMemory(dayData_v1.canisterMemorySizeData, intervalIndex);
                collectCycles(dayData_v1.canisterCyclesData, intervalIndex);
            };
        };
    };

    // Querying metrics functions

    public func getDayData(state: CanisterMonitoringState, dayDataId: DayDataId): ?DayData {
        do ? {
            state.dayDataMap.get(dayDataId)!;
        };
    };

    // Private

    // Private: dayData providing

    private func obtainDayDataFromMap(state: CanisterMonitoringState, dayDataId: DayDataId, granularitySeconds: Nat): DayData {
        let dayData: DayData = switch(state.dayDataMap.get(dayDataId)) {
            case (null) {
                //create new day data
                let newValue: DayData = createNewDayDataValue(granularitySeconds);
                state.dayDataMap.put(dayDataId, newValue);
                newValue;
            };
            case (?value) {
                //reuse existing day data
                value;
            };
        };
        dayData;
    };

    public func createNewDayDataValue(granularitySeconds: Nat): DayData {
        let numberOfIntervals = (24 * 60 * 60) / granularitySeconds;
        {
            updateCallsData: DayUpdateCallsCountData = Array.tabulateVar<Nat64>(numberOfIntervals, func(index: Nat) : Nat64 { 0 } );
            canisterHeapMemorySizeData: DayCanisterHeapMemorySizeData = Array.tabulateVar<Nat64>(numberOfIntervals, func(index: Nat) : Nat64 { 0 } );
            canisterMemorySizeData: DayCanisterMemorySizeData = Array.tabulateVar<Nat64>(numberOfIntervals, func(index: Nat) : Nat64 { 0 } );
            canisterCyclesData: DayCanisterCyclesData = Array.tabulateVar<Nat64>(numberOfIntervals, func(index: Nat) : Nat64 { 0 } );
        };
    };

    // Private: UpdateCalls

    private func tryToBumpUpdateCalls(updateCallsData: DayUpdateCallsCountData, intervalIndex: Nat): ?Nat64 {
        if (updateCallsData.size() > intervalIndex) {
            updateCallsData[intervalIndex] := updateCallsData[intervalIndex] + 1;
            return ?updateCallsData[intervalIndex];
        };
        return null;
    };

    // Private: HeapMemory

    private func collectHeapMemory(heapMemorySizeData: DayCanisterHeapMemorySizeData,  intervalIndex: Nat) {
        if (heapMemorySizeData.size() > intervalIndex) {
            heapMemorySizeData[intervalIndex] := Nat64.fromNat(Prim.rts_heap_size());
        };
    };

    // Private: Memory

    private func collectMemory(memorySizeData: DayCanisterMemorySizeData,  intervalIndex: Nat) {
        if (memorySizeData.size() > intervalIndex) {
            memorySizeData[intervalIndex] := Nat64.fromNat(Prim.rts_memory_size());
        };
    };

    // Private: Cycles

    private func collectCycles(cyclesData: DayCanisterCyclesData,  intervalIndex: Nat) {
        if (cyclesData.size() > intervalIndex) {
            cyclesData[intervalIndex] := Nat64.fromNat(ExperimentalCycles.balance());
        };
    };

    // Private: Conditions

    private func shouldCollectHeapMemoryAndCycles(newNumberOfUpdateCalls: Nat64): Bool {
        //if it is the first update call in interval
        newNumberOfUpdateCalls == 1;
    };
};