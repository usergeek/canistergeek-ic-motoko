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
import Bool "mo:base/Bool";

import CalculatorModule "calculatorModule";
import DateModule "dateModule";
import TypesModule "typesModule";

import LoggerTypesModule "logger/typesModule";
import LoggerCollector "logger/collectorModule";
import LoggerCalculator "logger/calculatorModule";
import LoggerStorage "logger/storageModule";

module Canistergeek {

    /****************************************************************
    * Monitor
    ****************************************************************/

    public type UpgradeData = TypesModule.UpgradeData;
    public type CanisterMetrics = TypesModule.CanisterMetrics;
    public type GetMetricsParameters = TypesModule.GetMetricsParameters;
    
    public type GetInformationRequest = TypesModule.GetInformationRequest;
    public type GetInformationResponse = TypesModule.GetInformationResponse;

    public type UpdateInformationRequest = TypesModule.UpdateInformationRequest;

    public class Monitor() {
        
        private var VERSION: Nat = 1;

        private var granularitySeconds: Nat = 60 * 5;

        private var state: TypesModule.CanisterMonitoringState = TypesModule.newCanisterMonitoringState();

        // PUBLIC API

        public func postupgrade(upgradeData: ?TypesModule.UpgradeData) {
            state := TypesModule.loadCanisterMonitoringState(upgradeData);
        };

        public func preupgrade() : TypesModule.UpgradeData {
            return TypesModule.prepareUpgradeData(state);
        };

        // legacy method - please use "updateInformation" method
        public func collectMetrics() {
            collectMetrics_int(false);
        };

        // legacy method - please use "getInformation" method
        public func getMetrics(parameters: GetMetricsParameters): ?CanisterMetrics {
            CalculatorModule.getMetrics(state, parameters);
        };

        public func updateInformation(request: UpdateInformationRequest) {
            switch (request.metrics) {
                case (null) {};
                case (?metricsRequest) {
                    switch(metricsRequest) {
                        case (#normal) {
                            collectMetrics_int(false);
                        };
                        case (#force) {
                            collectMetrics_int(true);
                        };
                    };
                };
            };
        };

        public func getInformation(request: GetInformationRequest): GetInformationResponse {
            var version: ?Nat = null;
            if (request.version) {
                version := ?VERSION;
            };
            var statusResponse: ?TypesModule.StatusResponse = TypesModule.getStatus(request.status);
            var metricsResponse: ?TypesModule.MetricsResponse = null;
            switch (request.metrics) {
                case (null) {};
                case (?metricsRequest) {
                    metricsResponse := ?{
                        metrics = CalculatorModule.getMetrics(state, metricsRequest.parameters);
                    };
                };
            };
            let response = {
                version = version;
                status = statusResponse;
                metrics = metricsResponse;
            };
            return response;
        };

        // Private

        private func collectMetrics_int(forceCollect: Bool) {
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
                                TypesModule.collectMetrics(state, dayDataId, currentDataIntervalIndexValue, granularitySeconds, forceCollect);
                            };
                        }
                    };
                }
            };
        };

        private func getDataIntervalIndex(time: Int): ?Nat {
            let secondsFromDayStart: ?Nat = DateModule.Date.secondsFromDayStart(time);
            switch(secondsFromDayStart) {
                case (null) { null; }; 
                case (?value) { ?(value / granularitySeconds); }
            };
        }
    };

    /****************************************************************
    * Logger
    ****************************************************************/
    
    public type LoggerUpgradeData = LoggerTypesModule.UpgradeData;
    public type LoggerMessage = LoggerTypesModule.Message;
    public type CanisterLogRequest = LoggerTypesModule.CanisterLogRequest;
    public type CanisterLogResponse = LoggerTypesModule.CanisterLogResponse;

    public class Logger() {

        private var state: LoggerTypesModule.State = LoggerTypesModule.newState(LoggerTypesModule.DEFAULT_MAX_LOG_MESSAGES_COUNT);

        // PUBLIC API

        public func postupgrade(upgradeData: ?LoggerTypesModule.UpgradeData) {
            state := LoggerTypesModule.loadState(upgradeData, state.maxCount);
        };

        public func preupgrade() : LoggerTypesModule.UpgradeData {
            return LoggerTypesModule.prepareUpgradeData(state);
        };

        public func logMessage(message: LoggerTypesModule.Message) : () {
            LoggerCollector.storeLogMessage(state, message, Time.now(), LoggerTypesModule.DEFAULT_MAX_LOG_MESSAGE_LENGTH);
        };

        public func getLog(request: ?LoggerTypesModule.CanisterLogRequest) : ?LoggerTypesModule.CanisterLogResponse {
            LoggerCalculator.getLog(state, request);
        };

        public func setMaxMessagesCount(newMaxMessagesCount: Nat) : () {
            LoggerStorage.setMaxMessagesCount(state, newMaxMessagesCount);
        };

        public func runTests() {
            LoggerStorage.runTests();
            LoggerCollector.runTests();
            LoggerCalculator.runTests();
        };
    };
}