import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Prim "mo:prim";
import Text "mo:base/Text";
import Time "mo:base/Time";

import CalculatorModule "calculatorModule";
import DateModule "dateModule";
import TypesModule "typesModule";

module Canistergeek {

    public type UpgradeData = TypesModule.UpgradeData;
    public type CanisterMetrics = CalculatorModule.CanisterMetrics;
    public type GetMetricsParameters = CalculatorModule.GetMetricsParameters;

    public class Monitor() {
        
        private var granularitySeconds: Nat = 60 * 5;

        private var state: TypesModule.CanisterMonitoringState = TypesModule.newCanisterMonitoringState();

        // PUBLIC API

        public func postupgrade(upgradeData: ?TypesModule.UpgradeData) {
            state := TypesModule.loadCanisterMonitoringState(upgradeData);
        };

        public func preupgrade() : TypesModule.UpgradeData {
            return TypesModule.prepareUpgradeData(state);
        };

        public func collectMetrics() {
            ignore do ? {
                let timeNow: Int = Time.now();
                let currentDataIntervalIndex: ?Nat = getDataIntervalIndex(timeNow);
                switch(currentDataIntervalIndex) {
                    case (null) {};
                    case (?currentDataIntervalIndexValue) {
                        switch(DateModule.Date.toDatePartsISO8601(timeNow)) {
                            case (null) {};
                            case (?(year, month, day)) {
                                let dayDataId: TypesModule.DayDataId = TypesModule.toDayDataId(year, month, day)!;
                                TypesModule.collectMetrics(state, dayDataId, currentDataIntervalIndexValue, granularitySeconds);
                            };
                        }
                    };
                }
            };
        };

        public func getMetrics(parameters: GetMetricsParameters): ?CanisterMetrics {
            CalculatorModule.getMetrics(state, parameters);
        };

        // Private

        private func getDataIntervalIndex(time: Int): ?Nat {
            let secondsFromDayStart: ?Nat = DateModule.Date.secondsFromDayStart(time);
            switch(secondsFromDayStart) {
                case (null) { null; }; 
                case (?value) { ?(value / granularitySeconds); }
            };
        }
    };
}