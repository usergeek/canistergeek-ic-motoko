import Buffer "mo:base/Buffer";
import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Text "mo:base/Text";

module {
    
    // Int/Nat
    public func intToNat(value: Int) : Nat { Nat64.toNat(Int64.toNat64(Int64.fromInt(value))) };
    public func intToNat64(value: Int) : Nat64 { Nat64.fromIntWrap(value) };
    public func natToInt(value: Nat) : Int { Int64.toInt(Int64.fromNat64(Nat64.fromNat(value))) };

    // Array
    public func sumOfArrayVarNat64(arr: [var Nat64]): Nat64 {
        var sum: Nat64 = 0;
        for (value in arr.vals()) {
            sum := sum + value;
        };
        sum;
    };

    public func bufferFromArray<T>(array: [T]) : Buffer.Buffer<T> {
        let buffer: Buffer.Buffer<T> = Buffer.Buffer<T>(array.size());
        for (item in array.vals()) {
            buffer.add(item);
        };
        buffer;
    };

    // Text

    /* Method copied from Motoko Base Library: Text.mo file */
    public func extractText(t : Text, i : Nat, j : Nat) : Text {
        let size = t.size();
        if (i == 0 and j == size) return t;
        assert (j <= size);
        let cs = t.chars();
        var r = "";
        var n = i;
        while (n > 0) {
            ignore cs.next();
            n -= 1;
        };
        n := j;
        while (n > 0) {
            switch (cs.next()) {
                case null { assert false };
                case (?c) { r #= Prim.charToText(c) }
            };
            n -= 1;
        };
        return r;
    };
}