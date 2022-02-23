import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Time "mo:base/Time";

import UtilsModule "../utilsModule";
import TypesModule "typesModule";
import StorageModule "storageModule";

module {

    public func storeLogMessage(state: TypesModule.State, message: TypesModule.Message, time: Time.Time, maxMessageLength: Nat) {
        let timeNanos = UtilsModule.intToNat64(time);
        let timeNanosCorrected = switch(StorageModule.getLastLogMessageTime(state)) {
            case (null) { timeNanos; };
            case (?previousTimeNanos) {
                if (timeNanos <= previousTimeNanos) {
                    previousTimeNanos + 1;
                } else {
                    timeNanos;
                };
            };
        };
        
        let validatedMessage = validateMessage(message, maxMessageLength);
        
        let logMessageData: TypesModule.LogMessagesData = {
            timeNanos = timeNanosCorrected;
            message = validatedMessage;
        };

        StorageModule.storeLogMessage(state, logMessageData);
    };

    private func validateMessage(message: TypesModule.Message, maxMessageLength: Nat): Text {
        if (Text.size(message) > maxMessageLength) {
            return UtilsModule.extractText(message, 0, maxMessageLength);
        };
        return message;
    };

    /****************************************************************
    * TESTS
    ****************************************************************/

    public func runTests() {
        testValidateMessage();
    };

    private func testValidateMessage() {
        assert(Text.equal(validateMessage("abcd", 5), "abcd"));
        assert(Text.equal(validateMessage("abcd", 4), "abcd"));
        assert(Text.equal(validateMessage("abcd", 3), "abc"));
    };

}