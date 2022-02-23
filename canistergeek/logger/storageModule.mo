import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Prelude "mo:base/Prelude";
import Text "mo:base/Text";

import TypesModule "typesModule";
import UtilsModule "../utilsModule";

module {
    
    public class LogMessageIterator(state: TypesModule.State, _index: Nat, _delta: Int, _nextCount: Nat) {
        public var index: Nat = _index;
        public var delta: Int = _delta;
        public var nextCount: Nat = _nextCount;

        public func next(): ?TypesModule.LogMessagesData {
            if (isDone()) {
                return null;
            } else {
                let message = getCurrentMessage();
                shiftToNext();
                return message;
            }
        };

        public func getCurrentMessage(): ?TypesModule.LogMessagesData {
            let idx: Nat = index % state.maxCount;
            return switch(state.queue.getOpt(idx)) {
                case (null) { null; };
                case (?v) { ?v; };
            };
        };

        public func isDone(): Bool {
            nextCount == 0;
        };
        
        public func shiftToNext() {
            index := UtilsModule.intToNat(UtilsModule.natToInt(index) + delta);
            nextCount := nextCount - 1;
        };

    };

    public func getLastLogMessageTime(state: TypesModule.State) : ?TypesModule.Nanos {
        if (state.queue.size() == 0) {
            return null;
        };
        let index: Nat = (state.maxCount + state.next - 1) % state.maxCount;

        return switch(state.queue.getOpt(index)) {
            case (null) { null; };
            case (?v) { ?v.timeNanos; }
        };
    };

    public func getLogMessagesCount(state: TypesModule.State) : Nat32 {
        Nat32.fromNat(state.queue.size())
    };

    public func getFirstLogMessageTime(state: TypesModule.State) : ?TypesModule.Nanos {
        if (state.queue.size() == 0) {
            null;
        } else {
            let idx = if (state.full) state.next else 0;
            switch(state.queue.getOpt(idx)) {
                case (null) { null; };
                case (?v) { ?v.timeNanos; };
            };
        };
    };

    public func storeLogMessage(state: TypesModule.State, logMessageData: TypesModule.LogMessagesData) {
        if (state.full) {
            state.queue.put(state.next, logMessageData);
        } else {
            state.queue.add(logMessageData);
        };

        state.next := state.next + 1;

        if (state.next == state.maxCount) {
            state.full := true;
            state.next := 0;
        }
    };

    public func setMaxMessagesCount(state: TypesModule.State, newMaxMessagesCount: Nat) {
        if (state.maxCount == newMaxMessagesCount) {
            return;
        };
        let newState: TypesModule.State = TypesModule.newState(newMaxMessagesCount);
        
        if (state.full) {
            let toRightSide: Int = state.queue.size() - 1;
            for (idxRightSide in Iter.range(state.next, toRightSide)) {
                storeLogMessage(newState, state.queue.get(idxRightSide));
            };
            if (state.next > 0) {
                let toLeftSide: Int = state.next - 1;
                for (idxLeftSide in Iter.range(0, toLeftSide)) {
                    storeLogMessage(newState, state.queue.get(idxLeftSide));
                };
            };
        } else {
            let to: Int = state.next - 1;
            for (idxLeftSide in Iter.range(0, to)) {
                storeLogMessage(newState, state.queue.get(idxLeftSide));
            };
        };

        state.queue := newState.queue;
        state.maxCount := newState.maxCount;
        state.next := newState.next;
        state.full := newState.full;
    };

    
    public func getLogMessagesIterator(state: TypesModule.State, fromTimeNanos: ?TypesModule.Nanos) : LogMessageIterator {
        if (state.queue.size() == 0) {
            return LogMessageIterator(state, 0, 0, 0);
        };

        let iterator: LogMessageIterator = if (state.full) {
            LogMessageIterator(state, state.next, 1, state.maxCount);
        } else {
            LogMessageIterator(state, 0, 1, state.next);
        };

        ignore do ? {
            let fromTimeNanosUnwrapped = fromTimeNanos!;
            while (not iterator.isDone() and iterator.getCurrentMessage()!.timeNanos <= fromTimeNanosUnwrapped) {
                iterator.shiftToNext();
            }
        };

        return iterator;
    };

    public func getLogMessagesIteratorReverse(state: TypesModule.State, upToTimeNanos: ?TypesModule.Nanos) : LogMessageIterator {
        if (state.queue.size() == 0) {
            return LogMessageIterator(state, 0, 0, 0);
        };

        let iterator: LogMessageIterator = if (state.full) {
            LogMessageIterator(state, state.maxCount + state.next - 1, -1, state.maxCount);
        } else {
            LogMessageIterator(state, state.next - 1, -1, state.next);
        };

        ignore do ? {
            let upToTimeNanosUnwrapped = upToTimeNanos!;
            while (not iterator.isDone() and iterator.getCurrentMessage()!.timeNanos >= upToTimeNanosUnwrapped) {
                iterator.shiftToNext();
            }
        };

        return iterator;
    };

    /****************************************************************
    * TESTS
    ****************************************************************/

    public func runTests() {
        testEmpty();
        testCyclic();
        testCyclicWithFrom();
        testSetMaxSize();
        testInfo();
    };

    private func testEmpty() {
        let state: TypesModule.State = TypesModule.newState(4);

        let iterator = getLogMessagesIterator(state, null);
        assert(iterator.next() == null);

        let iteratorReverse = getLogMessagesIteratorReverse(state, null);
        assert(iteratorReverse.next() == null);
    };
    
    private func testCyclic() {
        let state: TypesModule.State = TypesModule.newState(4);

        storeLogMessage(state, {timeNanos = 10; message = "time 10";});

        var iterator = getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 10, "time 10");
        assert(iterator.next() == null);
        
        iterator := getLogMessagesIteratorReverse(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 10, "time 10");
        assert(iterator.next() == null);

        storeLogMessage(state, {timeNanos = 20; message = "time 20";});
        storeLogMessage(state, {timeNanos = 30; message = "time 30";});

        iterator := getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 10, "time 10");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        assert(iterator.next() == null);

        iterator := getLogMessagesIteratorReverse(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 10, "time 10");
        assert(iterator.next() == null);

        storeLogMessage(state, {timeNanos = 40; message = "time 40";});

        iterator := getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 10, "time 10");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        assert(iterator.next() == null);

        iterator := getLogMessagesIteratorReverse(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 10, "time 10");
        assert(iterator.next() == null);

        storeLogMessage(state, {timeNanos = 50; message = "time 50";});
        iterator := getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 50, "time 50");
        assert(iterator.next() == null);

        iterator := getLogMessagesIteratorReverse(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 50, "time 50");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        assert(iterator.next() == null);
    };
    
    private func testCyclicWithFrom() {
        let state: TypesModule.State = TypesModule.newState(4);

        storeLogMessage(state, {timeNanos = 10; message = "time 10";});
        storeLogMessage(state, {timeNanos = 20; message = "time 20";});
        storeLogMessage(state, {timeNanos = 30; message = "time 30";});
        storeLogMessage(state, {timeNanos = 40; message = "time 40";});

        var iterator = getLogMessagesIterator(state, ?20);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        assert(iterator.next() == null);
        
        iterator := getLogMessagesIteratorReverse(state, ?20);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 10, "time 10");
        assert(iterator.next() == null);
    };

    private func testSetMaxSize() {
        let state: TypesModule.State = TypesModule.newState(2);

        setMaxMessagesCount(state, 3);
        var iterator = getLogMessagesIterator(state, null);
        assert(iterator.next() == null);

        storeLogMessage(state, {timeNanos = 10; message = "time 10";});
        storeLogMessage(state, {timeNanos = 20; message = "time 20";});
        setMaxMessagesCount(state, 4);

        iterator := getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 10, "time 10");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        assert(iterator.next() == null);

        storeLogMessage(state, {timeNanos = 30; message = "time 30";});
        storeLogMessage(state, {timeNanos = 40; message = "time 40";});
        storeLogMessage(state, {timeNanos = 50; message = "time 50";});
        setMaxMessagesCount(state, 5);

        iterator := getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 50, "time 50");
        assert(iterator.next() == null);

        storeLogMessage(state, {timeNanos = 60; message = "time 60";});

        iterator := getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 20, "time 20");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 30, "time 30");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 50, "time 50");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 60, "time 60");
        assert(iterator.next() == null);

        setMaxMessagesCount(state, 3);

        iterator := getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 50, "time 50");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 60, "time 60");
        assert(iterator.next() == null);

        setMaxMessagesCount(state, 6);
        setMaxMessagesCount(state, 3);

        iterator := getLogMessagesIterator(state, null);
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 40, "time 40");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 50, "time 50");
        test_validateMessage(test_unwrapIteratorNextValue(iterator), 60, "time 60");
        assert(iterator.next() == null);
    };

    private func testInfo() {
        let state: TypesModule.State = TypesModule.newState(2);

        assert(getLogMessagesCount(state) == 0);
        assert(getFirstLogMessageTime(state) == null);
        assert(getLastLogMessageTime(state) == null);

        storeLogMessage(state, {timeNanos = 10; message = "time 10";});
        assert(getLogMessagesCount(state) == 1);
        assert(test_unwrapFirstLogMessageTime(state) == 10);
        assert(test_unwrapLastLogMessageTime(state) == 10);

        storeLogMessage(state, {timeNanos = 20; message = "time 20";});
        assert(getLogMessagesCount(state) == 2);
        assert(test_unwrapFirstLogMessageTime(state) == 10);
        assert(test_unwrapLastLogMessageTime(state) == 20);

        storeLogMessage(state, {timeNanos = 30; message = "time 30";});
        assert(getLogMessagesCount(state) == 2);
        assert(test_unwrapFirstLogMessageTime(state) == 20);
        assert(test_unwrapLastLogMessageTime(state) == 30);

        storeLogMessage(state, {timeNanos = 40; message = "time 40";});
        assert(getLogMessagesCount(state) == 2);
        assert(test_unwrapFirstLogMessageTime(state) == 30);
        assert(test_unwrapLastLogMessageTime(state) == 40);
    };

    private func test_unwrapIteratorNextValue(iterator: LogMessageIterator) : TypesModule.LogMessagesData {
        switch(iterator.next()) {
            case (null) { 
                Prelude.unreachable();
            };
            case (?v) { v; };
        };
    };

    private func test_unwrapFirstLogMessageTime(state: TypesModule.State) : TypesModule.Nanos {
        switch(getFirstLogMessageTime(state)) {
            case (null) { 
                Prelude.unreachable();
            };
            case (?v) { v; };
        };
    };

    private func test_unwrapLastLogMessageTime(state: TypesModule.State) : TypesModule.Nanos {
        switch(getLastLogMessageTime(state)) {
            case (null) { 
                Prelude.unreachable();
            };
            case (?v) { v; };
        };
    };

    private func test_validateMessage(message: TypesModule.LogMessagesData, nanos: TypesModule.Nanos, text: TypesModule.Message) {
        assert(message.timeNanos == nanos);
        assert(Text.equal(message.message, text));
    }
};