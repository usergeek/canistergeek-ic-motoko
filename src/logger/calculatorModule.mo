import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Prelude "mo:base/Prelude";

import StorageModule "storageModule";
import TypesModule "typesModule";
import CollectorModule "collectorModule";

module {

    private let MAX_CHUNK_SIZE : Nat = 1024;

    public func getLog(state: TypesModule.State, request: ?TypesModule.CanisterLogRequest) : ?TypesModule.CanisterLogResponse {
        switch(request) {
            case (null) { null; };
            case (?requestUnwrapped) {
                switch (requestUnwrapped) {
                    case (#getMessagesInfo) {
                        switch (getLogMessagesInfo(state)) {
                            case (null) { null; };
                            case (?v) { 
                                ?#messagesInfo v;
                            };
                        };
                    };
                    case (#getMessages params) {
                        switch (getLogMessages(state, params)) {
                            case (null) { null; };
                            case (?v) { 
                                ?#messages v;
                            };
                        };
                    };
                    case (#getLatestMessages params) {
                        switch (getLatestLogMessages(state, params)) {
                            case (null) { null; };
                            case (?v) { 
                                ?#messages v;
                            };
                        };
                    };
                };
            };
        };
    };

    private func getLogMessagesInfo(state: TypesModule.State) : ?TypesModule.CanisterLogMessagesInfo {
        let count = StorageModule.getLogMessagesCount(state);
        let features: [?TypesModule.CanisterLogFeature] = [?#filterMessageByContains];
        if (count == 0) {
            ?{
                count = 0;
                firstTimeNanos = null;
                lastTimeNanos = null;
                features = features;
            };
        } else {
            ?{
                count = count;
                firstTimeNanos = StorageModule.getFirstLogMessageTime(state);
                lastTimeNanos = StorageModule.getLastLogMessageTime(state);
                features = features;
            };
        };
    };

    private func getLogMessages(state: TypesModule.State, parameters: TypesModule.GetLogMessagesParameters) : ?TypesModule.CanisterLogMessages {
        return iterateLogMessagesInt(state, false, parameters.fromTimeNanos, Nat32.toNat(parameters.count), parameters.filter);
    };

    private func getLatestLogMessages(state: TypesModule.State, parameters: TypesModule.GetLatestLogMessagesParameters) : ?TypesModule.CanisterLogMessages {
        return iterateLogMessagesInt(state, true, parameters.upToTimeNanos, Nat32.toNat(parameters.count), parameters.filter);
    };

    private func iterateLogMessagesInt(state: TypesModule.State, reverse: Bool, time: ?TypesModule.Nanos, count: Nat, filter: ?TypesModule.GetLogMessagesFilter) : ?TypesModule.CanisterLogMessages {
        if (count == 0 or count > MAX_CHUNK_SIZE) {
            return null;
        };
        if (state.queue.size() == 0) {
            return ?{
                data = [];
                lastAnalyzedMessageTimeNanos = null;
            };
        };

        let iterator: Iter.Iter<TypesModule.LogMessagesData> = if (reverse) {
            StorageModule.getLogMessagesIteratorReverse(state, time);
        } else {
            StorageModule.getLogMessagesIterator(state ,time);
        };

        let data: Buffer.Buffer<TypesModule.LogMessagesData> = Buffer.Buffer<TypesModule.LogMessagesData>(count);

        let (pattern, analizeCount): (?Text.Pattern, Nat) = switch(filter) {
            case (null) { (null, count); };
            case (?filterUnwrapped) {
                let filterRegexPattern: ?Text.Pattern = switch(filterUnwrapped.messageContains) {
                    case (null) { null; };
                    case (?v) { ?#text v; };
                };
                (filterRegexPattern, Nat32.toNat(filterUnwrapped.analyzeCount));
            };
        };

        var lastAnalyzedMessageTimeNanos: ?TypesModule.Nanos = null;

        var counter: Nat = 0;

        label LOOP loop {
            switch(iterator.next()) {
                case (null) { 
                    break LOOP;
                };
                case (?message) {
                    if (isValidByFilterRegex(message, pattern)) {
                        data.add(message);
                    };

                    counter := counter + 1;

                    lastAnalyzedMessageTimeNanos := ?message.timeNanos;

                    if (data.size() >= count or counter >= analizeCount) {
                        break LOOP;
                    }
                };
            };
        };

        return ?{
            data = data.toArray();
            lastAnalyzedMessageTimeNanos = lastAnalyzedMessageTimeNanos;
        };
    };

    private func isValidByFilterRegex(logMessageData: TypesModule.LogMessagesData, pattern: ?Text.Pattern) : Bool {
        return switch(pattern) {
            case (null) {
                return true;
            };
            case (?value) {
                return Text.contains(logMessageData.message, value)
            };
        }
    };

    /****************************************************************
    * TESTS
    ****************************************************************/

    public func runTests() {
        testEmptyLogMessages();
        testChunkLogMessages();
        testChunkLatestLogMessages();
        testFilterLogMessages();
        testLogMessagesInfo();
    };

    private func testEmptyLogMessages() {
        let state: TypesModule.State = TypesModule.newState(4);

        var params: TypesModule.GetLogMessagesParameters = {
            count = 0;
            fromTimeNanos = null;
            filter = null;
        };

        assert(getLogMessages(state, params) == null);
        
        params := {
            count = 10;
            fromTimeNanos = null;
            filter = null;
        };

        var messages = test_unwrapLogMessages(state, params);
        assert(messages.data.size() == 0);
        assert(messages.lastAnalyzedMessageTimeNanos == null);
    };

    private func testChunkLogMessages() {
        let state: TypesModule.State = TypesModule.newState(4);

        CollectorModule.storeLogMessage(state, "1 message", 1, 10);
        CollectorModule.storeLogMessage(state, "2 message", 2, 10);
        CollectorModule.storeLogMessage(state, "3 message", 3, 10);
        CollectorModule.storeLogMessage(state, "4 message", 3, 3); // check same nanos!!! 3 must be stored as 4!
        
        var params: TypesModule.GetLogMessagesParameters = {
            count = 0;
            fromTimeNanos = null;
            filter = null;
        };
        assert(getLogMessages(state, params) == null);

        params := {
            count = 10;
            fromTimeNanos = null;
            filter = null;
        };
        var messages = test_unwrapLogMessages(state, params);
        assert(messages.data.size() == 4);
        assert(Text.equal(messages.data.get(0).message, "1 message"));
        assert(Text.equal(messages.data.get(1).message, "2 message"));
        assert(Text.equal(messages.data.get(2).message, "3 message"));
        assert(Text.equal(messages.data.get(3).message, "4 m"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?4);

        params := {
            count = 2;
            fromTimeNanos = null;
            filter = null;
        };
        messages := test_unwrapLogMessages(state, params);
        assert(messages.data.size() == 2);
        assert(Text.equal(messages.data.get(0).message, "1 message"));
        assert(Text.equal(messages.data.get(1).message, "2 message"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?2);

        params := {
            count = 1;
            fromTimeNanos = messages.lastAnalyzedMessageTimeNanos;
            filter = null;
        };
        messages := test_unwrapLogMessages(state, params);
        assert(messages.data.size() == 1);
        assert(Text.equal(messages.data.get(0).message, "3 message"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?3);
    };

    private func testChunkLatestLogMessages() {
        let state: TypesModule.State = TypesModule.newState(4);

        CollectorModule.storeLogMessage(state, "1 message", 1, 10);
        CollectorModule.storeLogMessage(state, "2 message", 2, 10);
        CollectorModule.storeLogMessage(state, "3 message", 3, 10);
        CollectorModule.storeLogMessage(state, "4 message", 4, 3);
        
        var params: TypesModule.GetLatestLogMessagesParameters = {
            count = 0;
            upToTimeNanos = null;
            filter = null;
        };
        assert(getLatestLogMessages(state, params) == null);

        params := {
            count = 10;
            upToTimeNanos = null;
            filter = null;
        };
        var messages = test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 4);
        assert(Text.equal(messages.data.get(0).message, "4 m"));
        assert(Text.equal(messages.data.get(1).message, "3 message"));
        assert(Text.equal(messages.data.get(2).message, "2 message"));
        assert(Text.equal(messages.data.get(3).message, "1 message"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?1);

        params := {
            count = 2;
            upToTimeNanos = null;
            filter = null;
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 2);
        assert(Text.equal(messages.data.get(0).message, "4 m"));
        assert(Text.equal(messages.data.get(1).message, "3 message"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?3);

        params := {
            count = 1;
            upToTimeNanos = messages.lastAnalyzedMessageTimeNanos;
            filter = null;
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 1);
        assert(Text.equal(messages.data.get(0).message, "2 message"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?2);
    };

    private func testFilterLogMessages() {
        var state: TypesModule.State = TypesModule.newState(4);

        CollectorModule.storeLogMessage(state, "1 message abc", 1, 1024);
        CollectorModule.storeLogMessage(state, "2 message", 2, 1024);
        CollectorModule.storeLogMessage(state, "3 message abc", 3, 1024);
        CollectorModule.storeLogMessage(state, "4 message", 4, 1024);

        var params: TypesModule.GetLatestLogMessagesParameters = {
            count = 1;
            upToTimeNanos = null;
            filter = ?{
                messageContains = ?"abc";
                messageRegex = null;
                analyzeCount = 1;
            };
        };
        var messages = test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 0);
        assert(messages.lastAnalyzedMessageTimeNanos == ?4);

        params := {
            count = 1;
            upToTimeNanos = null;
            filter = ?{
                messageContains = ?"abc";
                messageRegex = null;
                analyzeCount = 2;
            };
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 1);
        assert(Text.equal(messages.data.get(0).message, "3 message abc"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?3);
                
        params := {
            count = 4;
            upToTimeNanos = null;
            filter = ?{
                messageContains = ?"abc";
                messageRegex = null;
                analyzeCount = 4;
            };
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 2);
        assert(Text.equal(messages.data.get(0).message, "3 message abc"));
        assert(Text.equal(messages.data.get(1).message, "1 message abc"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?1);

        params := {
            count = 4;
            upToTimeNanos = null;
            filter = ?{
                messageContains = ?"abc";
                messageRegex = null;
                analyzeCount = 3;
            };
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 1);
        assert(Text.equal(messages.data.get(0).message, "3 message abc"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?2);

        params := {
            count = 4;
            upToTimeNanos = ?messages.data.get(0).timeNanos;
            filter = ?{
                messageContains = ?"abc";
                messageRegex = null;
                analyzeCount = 4;
            };
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 1);
        assert(Text.equal(messages.data.get(0).message, "1 message abc"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?1);

        state := TypesModule.newState(10);

        CollectorModule.storeLogMessage(state, "1 message abc", 1, 1024);
        CollectorModule.storeLogMessage(state, "2 message abc", 2, 1024);
        CollectorModule.storeLogMessage(state, "3 message def", 3, 1024);
        CollectorModule.storeLogMessage(state, "4 message def", 4, 1024);
        CollectorModule.storeLogMessage(state, "5 message def", 5, 1024);
        CollectorModule.storeLogMessage(state, "6 message abc", 6, 1024);
        CollectorModule.storeLogMessage(state, "7 message abc", 7, 1024);
        CollectorModule.storeLogMessage(state, "8 message abc", 8, 1024);
        CollectorModule.storeLogMessage(state, "9 message abc", 9, 1024);
        CollectorModule.storeLogMessage(state, "10 message abc", 10, 1024);

        let filter: ?TypesModule.GetLogMessagesFilter = ?{
            messageContains = ?"def";
                messageRegex = null;
            analyzeCount = 3;
        };
        params := {
            count = 3;
            upToTimeNanos = null;
            filter = filter;
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 0);
        assert(messages.lastAnalyzedMessageTimeNanos == ?8);

        params := {
            count = 3;
            upToTimeNanos = messages.lastAnalyzedMessageTimeNanos;
            filter = filter;
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 1);
        assert(Text.equal(messages.data.get(0).message, "5 message def"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?5);

        params := {
            count = 3;
            upToTimeNanos = messages.lastAnalyzedMessageTimeNanos;
            filter = filter;
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 2);
        assert(Text.equal(messages.data.get(0).message, "4 message def"));
        assert(Text.equal(messages.data.get(1).message, "3 message def"));
        assert(messages.lastAnalyzedMessageTimeNanos == ?2);

        params := {
            count = 3;
            upToTimeNanos = messages.lastAnalyzedMessageTimeNanos;
            filter = filter;
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 0);
        assert(messages.lastAnalyzedMessageTimeNanos == ?1);

        params := {
            count = 3;
            upToTimeNanos = messages.lastAnalyzedMessageTimeNanos;
            filter = filter;
        };
        messages := test_unwrapLatestLogMessages(state, params);
        assert(messages.data.size() == 0);
        assert(messages.lastAnalyzedMessageTimeNanos == null);
    };

    private func testLogMessagesInfo() {
        let state: TypesModule.State = TypesModule.newState(4);
        let features: [?TypesModule.CanisterLogFeature] = [?#filterMessageByContains];

        assert(getLogMessagesInfo(state) == ?{
            count = 0;
            firstTimeNanos = null;
            lastTimeNanos = null;
            features = features;
        });

        CollectorModule.storeLogMessage(state, "1 message", 1, 1024);
        assert(getLogMessagesInfo(state) == ?{
            count = 1;
            firstTimeNanos = ?1;
            lastTimeNanos = ?1;
            features = features;
        });

        CollectorModule.storeLogMessage(state, "2 message", 2, 1024);
        CollectorModule.storeLogMessage(state, "3 message", 3, 1024);
        CollectorModule.storeLogMessage(state, "4 message", 4, 1024);
        CollectorModule.storeLogMessage(state, "5 message", 5, 1024);
        assert(getLogMessagesInfo(state) == ?{
            count = 4;
            firstTimeNanos = ?2;
            lastTimeNanos = ?5;
            features = features;
        });
    };

    private func test_unwrapLogMessages(state: TypesModule.State, params: TypesModule.GetLogMessagesParameters) : TypesModule.CanisterLogMessages {
        switch(getLogMessages(state, params)) {
            case (null) { 
                Prelude.unreachable();
            };
            case (?v) { v; };
        };
    };
    
    private func test_unwrapLatestLogMessages(state: TypesModule.State, params: TypesModule.GetLatestLogMessagesParameters) : TypesModule.CanisterLogMessages {
        switch(getLatestLogMessages(state, params)) {
            case (null) { 
                Prelude.unreachable();
            };
            case (?v) { v; };
        };
    };
};