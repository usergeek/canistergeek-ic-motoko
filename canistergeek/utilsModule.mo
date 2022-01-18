import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";

module {
    
    // Int/Nat
    public func intToNat(value: Int) : Nat { Nat64.toNat(Int64.toNat64(Int64.fromInt(value))) };
    public func natToInt(value: Nat) : Int { Int64.toInt(Int64.fromNat64(Nat64.fromNat(value))) };

    // Array
    public func sumOfArrayVarNat64(arr: [var Nat64]): Nat64 {
        var sum: Nat64 = 0;
        for (value in arr.vals()) {
            sum := sum + value;
        };
        sum;
    };
}