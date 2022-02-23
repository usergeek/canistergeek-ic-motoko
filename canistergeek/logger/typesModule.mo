import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";

import UtilsModule "../utilsModule";

module {

    // Constants

    public let DEFAULT_MAX_LOG_MESSAGES_COUNT : Nat = 10_000;
    public let DEFAULT_MAX_LOG_MESSAGE_LENGTH : Nat = 4_096;

    // Data types

    public type Message = Text;
    public type Nanos = Nat64;

    public type LogMessagesData = {
        timeNanos: Nanos;
        message: Text;
    };

    private type LogMessageQueue = Buffer.Buffer<LogMessagesData>;
    
    // State

    public type State = {
        var queue: LogMessageQueue;
        var maxCount: Nat;
        var next: Nat;
        var full: Bool;
    };

    // View

    public type CanisterLogRequest = {
        #getMessagesInfo;
        #getMessages : GetLogMessagesParameters;
        #getLatestMessages : GetLatestLogMessagesParameters;
    };

    public type CanisterLogResponse = {
        #messagesInfo: CanisterLogMessagesInfo;
        #messages : CanisterLogMessages;
    };

    public type GetLogMessagesFilter = {
        messageContains: ?Text;
        messageRegex: ?Text;
        analyzeCount: Nat32;
    };

    public type GetLogMessagesParameters = {
        count: Nat32;
        fromTimeNanos: ?Nanos;
        filter: ?GetLogMessagesFilter;
    };
    
    public type GetLatestLogMessagesParameters = {
        count: Nat32;
        upToTimeNanos: ?Nanos;
        filter: ?GetLogMessagesFilter;
    };

    public type CanisterLogMessages = {
        data: [LogMessagesData];
        lastAnalyzedMessageTimeNanos: ?Nanos;
    };

    public type CanisterLogFeature = {
        #filterMessageByContains;
        #filterMessageByRegex;
    };

    public type CanisterLogMessagesInfo = {
        count: Nat32;
        firstTimeNanos: ?Nanos;
        lastTimeNanos: ?Nanos;
        features: [?CanisterLogFeature];
    };

    // Post/Pre upgrade types

    private type LogMessageArray = [LogMessagesData];

    public type UpgradeData = {
        #v1 : {
            queue: LogMessageArray;
            maxCount: Nat;
            next: Nat;
            full: Bool;
        };
    };

    // Init / Pre-Post Upgrade functions

    public func newState(maxMessagesCount: Nat): State {
        let defaultUpgradeData: UpgradeData = createDefaultUpgradeData_v1(maxMessagesCount);
        return loadState(?defaultUpgradeData, maxMessagesCount);
    };

    public func loadState(upgradeData: ?UpgradeData, defaultMaxMessagesCount: Nat): State {
        return switch(upgradeData) {
            case null { newState(defaultMaxMessagesCount); };
            case (?upgradeDataValue) {
                let migratedUpgradeData: UpgradeData = migrateUpgradeData(upgradeDataValue);
                let state: State = createStateFromMigratedUpgradeData(migratedUpgradeData);
                return state;
            };
        };
    };

    public func prepareUpgradeData(state: State): UpgradeData {
        let upgradeData : UpgradeData = prepareCurrentUpgradeData_v1(state);
        return upgradeData;
    };

    // Stable data migration

    private func createDefaultUpgradeData_v1(maxMessagesCount: Nat): UpgradeData {
        return #v1 {
            queue = [];
            maxCount = maxMessagesCount;
            next = 0;
            full = false;
        };
    };

    private func prepareCurrentUpgradeData_v1(state: State): UpgradeData {
        let upgradeData : UpgradeData = #v1 {
            queue = state.queue.toArray();
            maxCount = state.maxCount;
            next = state.next;
            full = state.full;
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

    private func createStateFromMigratedUpgradeData(upgradeData: UpgradeData): State {
        switch (upgradeData) {
            case (#v1 value) {
                return {
                    var queue = UtilsModule.bufferFromArray<LogMessagesData>(value.queue);
                    var maxCount = value.maxCount;
                    var next = value.next;
                    var full = value.full;
                };
            };
        };
    };

    
}