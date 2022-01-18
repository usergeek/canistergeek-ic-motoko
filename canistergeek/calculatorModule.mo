import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import DateModule "dateModule";
import TypesModule "typesModule";
import UtilsModule "utilsModule";

module {

    public type MetricsGranularity = TypesModule.MetricsGranularity;
    public type CanisterMetrics = TypesModule.CanisterMetrics;

    public type GetMetricsParameters = {
        granularity: MetricsGranularity;
        dateFromMillis: Nat;
        dateToMillis: Nat;
    };

    private let HOURLY_MAX_DAYS = 9; //used to show last eight (8) 24h-intervals
    private let DAILY_MAX_DAYS = 365;

    private func avgOfArrayFilter(value: Nat): Bool { return value > 0; };

    public func getMetrics(state: TypesModule.CanisterMonitoringState, parameters: GetMetricsParameters): ?CanisterMetrics {
        do ? {
            //millis to nanos
            let dateFromNanos = parameters.dateFromMillis * 1_000_000;
            let dateToNanos = parameters.dateToMillis * 1_000_000;
            //if dateFrom is before dateTo 
            if (dateToNanos >= dateFromNanos) {
                //get (year, month, day) parts from dateTo ignoring time of a day
                let dateFromISO8601Parts: DateModule.ISO8601.DatePartsISO8601 = DateModule.Date.toDatePartsISO8601(dateFromNanos)!;
                let dateToISO8601Parts: DateModule.ISO8601.DatePartsISO8601 = DateModule.Date.toDatePartsISO8601(dateToNanos)!;

                //set time to start of a days (0h:0m:0s) to shift by days correctly
                let dateFromDayStartTime = DateModule.Date.datePartsISO8601ToTime(dateFromISO8601Parts)!;
                let dateToDayStartTime = DateModule.Date.datePartsISO8601ToTime(dateToISO8601Parts)!;

                //create a calendar using start of a dateTo day
                let calendar = DateModule.Calendar.Calendar();
                calendar.updateTime(dateToDayStartTime);

                switch(parameters.granularity) {
                    case (#hourly) {
                        let metricsDataBufferReverse: Buffer.Buffer<TypesModule.HourlyMetricsData> = Buffer.Buffer<TypesModule.HourlyMetricsData>(30);
                        var daysAnalyzed = 0;
                        //iterate days from dayTo day backwards
                        //also check maximum number of analyzed days for hourly
                        label iterateDays loop {
                            if (calendar.getTime() < dateFromDayStartTime or daysAnalyzed >= HOURLY_MAX_DAYS) {
                                break iterateDays;
                            };
                            //get (year, month, day) parts from calendar
                            let (year, month, day): (Nat, Nat, Nat) = calendar.getISO8601DateParts();
                            //calculate dayDataId for particular day
                            let dayDataId: TypesModule.DayDataId = TypesModule.toDayDataId(year, month, day)!;
                            ignore do ? {
                                //obtain dayData structure
                                let currentDayData: TypesModule.DayData = TypesModule.getDayData(state, dayDataId)!;
                                let intervalTimeMillis: Int = calendar.getTime() / 1_000_000;
                                //add to buffer
                                metricsDataBufferReverse.add({
                                    timeMillis = intervalTimeMillis;
                                    updateCalls = Array.freeze(currentDayData.updateCallsData);
                                    canisterHeapMemorySize = Array.freeze(currentDayData.canisterHeapMemorySizeData);
                                    canisterMemorySize = Array.freeze(currentDayData.canisterMemorySizeData);
                                    canisterCycles = Array.freeze(currentDayData.canisterCyclesData);
                                })
                            };
                            //next iteration...
                            daysAnalyzed := daysAnalyzed + 1;
                            calendar.addDays(-1);
                        };
                        return ?{
                            data = #hourly (metricsDataBufferReverse.toArray());
                        };
                    };
                    case (#daily) {
                        let metricsDataBufferReverse: Buffer.Buffer<TypesModule.DailyMetricsData> = Buffer.Buffer<TypesModule.DailyMetricsData>(30);
                        var daysAnalyzed = 0;
                        //iterate days from dayTo day backwards
                        //also check maximum number of analyzed days for daily
                        while (daysAnalyzed < DAILY_MAX_DAYS and calendar.getTime() >= dateFromDayStartTime and calendar.getTime() <= dateToNanos) {
                            //get (year, month, day) parts from calendar
                            let (year, month, day): (Nat, Nat, Nat) = calendar.getISO8601DateParts();
                            //calculate dayDataId for particular day 
                            let dayDataId: TypesModule.DayDataId = TypesModule.toDayDataId(year, month, day)!;
                            ignore do ? {
                                //obtain dayData structure
                                let currentDayData: TypesModule.DayData = TypesModule.getDayData(state, dayDataId)!;
                                let intervalTimeMillis: Int = calendar.getTime() / 1_000_000;

                                let totalUpdateCalls = UtilsModule.sumOfArrayVarNat64(currentDayData.updateCallsData);
                                let averageHeapMemorySize = calculateNumericMetricsEntity(currentDayData.canisterHeapMemorySizeData);
                                let averageMemorySize = calculateNumericMetricsEntity(currentDayData.canisterMemorySizeData);
                                let averageCycles = calculateNumericMetricsEntity(currentDayData.canisterCyclesData);

                                //add to buffer
                                metricsDataBufferReverse.add({
                                    timeMillis = intervalTimeMillis;
                                    updateCalls = totalUpdateCalls;
                                    canisterHeapMemorySize = averageHeapMemorySize;
                                    canisterMemorySize = averageMemorySize;
                                    canisterCycles = averageCycles;
                                })
                            };
                            //next iteration...
                            daysAnalyzed := daysAnalyzed + 1;
                            calendar.addDays(-1);
                        };
                        return ?{
                            data = #daily (metricsDataBufferReverse.toArray());
                        };
                    };
                };
            };
            return null;
        };
    };

    private func calculateNumericMetricsEntity(arr: [var Nat64]): TypesModule.NumericEntity {
        let arraySize = arr.size();

        var sumForAvg: Nat64 = 0;
        var countForAvg: Nat64 = 0;
        var min: Nat64 = 0;
        var max: Nat64 = 0;
        var first: Nat64 = 0;
        var last: Nat64 = 0;
        var avg: Nat64 = 0;

        if (arraySize > 0) {
            first := arr[0];
            last := arr[arraySize - 1]
        };

        for (value in arr.vals()) {
            let isPositive = value > 0;
            if (isPositive) {
                if (min == 0 or value < min) {
                    min := value;
                }
            };
            if (value > max) {
                max := value;
            };
            if (isPositive) {
                sumForAvg := sumForAvg + value;
                countForAvg := countForAvg + 1;
            };
        };
        if (countForAvg > 0) {
            avg := sumForAvg / countForAvg;
        };
        {
            min = min;
            max = max;
            first = first;
            last = last;
            avg = avg;
        }
    };
};