# Canistergeek-IC-Motoko

Canistergeek-IC-Motoko is the open-source tool for Internet Computer to track your project canisters cycles and memory status.

Canistergeek-IC-Motoko can be integrated into your canisters as motoko library which exposes the `Monitor` - public class that collects the data for specific canister by 5 minutes intervals.

Canistergeek-IC-Motoko should be used together with [Canistergeek-IC-JS](https://github.com/usergeek/canistergeek-ic-js) - Javascript library that fetches the data from canisters, perform all necessary calculations and displays it on a webpage 

Stored data consumes ~6.5Mb per year per canister (assuming data points every 5 minutes).

### Collecting the data

Data can be collected in two ways: automatically and manually

1. Manually by calling `collectCanisterMetrics` public method
2. Automatically by calling `canistergeekMonitor.collectMetrics();` in "update" methods in your canister to guarantee desired "Collect metrics" frequency. In some cases you may want to collect metrics in every "update" method to get the full picture in realtime and see how "update" methods influence canister price and capacity.

#### Update calls

Monitor collects the number of canister update calls

#### Cycles

Monitor collects how many cycles left at particular time using `ExperimentalCycles.balance()`.

#### Memory

Monitor collects how many memory bytes the canister consumes at particular time using `Prim.rts_memory_size()`.

#### Heap Memory

Monitor collects how many heap memory bytes the canister consumes at particular time using `Prim.rts_heap_size()`.


## Installation

Copy `canistergeek` folder from this repository into your project.

## Usage

Please perform the following steps

#### Import library in your canister

```motoko
import Canistergeek "../canistergeek/canistergeek";
```

#### Initialize the monitor

Initialize Canistergeek Monitor as a private constant.

```motoko
actor {

    private let canistergeekMonitor = Canistergeek.Monitor();

}
```

#### Add post/pre upgrade hooks

Add stable variable and implement pre/post upgrade hooks.
This step is necessary to save collected data between canister upgrades.

```motoko
actor {
    
    stable var _canistergeekMonitorUD: ? Canistergeek.UpgradeData = null;
    
    system func preupgrade() {
        _canistergeekMonitorUD := ? canistergeekMonitor.preupgrade();
    };

    system func postupgrade() { 
        canistergeekMonitor.postupgrade(_canistergeekMonitorUD);
        _canistergeekMonitorUD := null;
    };
    
}
```

#### Implement public methods

Implement public methods in the canister in order to query collected data and optionally force collecting the data

```motoko
actor {
    
    // CANISTER MONITORING

    /**
    * Returns collected data based on passed parameters.
    * Called from browser.
    */
    public query ({caller}) func getCanisterMetrics(parameters: Canistergeek.GetMetricsParameters): async ?Canistergeek.CanisterMetrics {
        validateCaller(caller);
        canistergeekMonitor.getMetrics(parameters);
    };

    /**
    * Force collecting the data at current time.
    * Called from browser or any canister "update" method.
    */
    public shared ({caller}) func collectCanisterMetrics(): async () {
        validateCaller(caller);
        canistergeekMonitor.collectMetrics();
    };
    
    private func validateCaller(principal: Principal) : () {
        //limit access here!
    };
    
}
```

#### Adjust "update" methods

Call `canistergeekMonitor.collectMetrics()` method in all "update" methods in your canister in order to automatically collect all data.

```motoko
actor {
    
    public shared ({caller}) func doThis(): async () {
        canistergeekMonitor.collectMetrics();
        // rest part of the your method...
    };
    
    public shared ({caller}) func doThat(): async () {
        canistergeekMonitor.collectMetrics();
        // rest part of the your method...
    };
    
}
```

#### LIMIT ACCESS TO YOUR DATA

🔴🔴🔴 We highly recommend limiting access by checking caller principal 🔴🔴🔴


```motoko
actor {

    private let adminPrincipal: Text = "xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxx";
    
    private func validateCaller(principal: Principal) : () {
        //data is available only for specific principal
        if (not (Principal.toText(principal) == adminPrincipal)) {
            Prelude.unreachable();
        }
    };
    
}
```

## Full Example

```motoko
import Canistergeek "../canistergeek/canistergeek";

actor {

    stable var _canistergeekMonitorUD: ? Canistergeek.UpgradeData = null;
    private let canistergeekMonitor = Canistergeek.Monitor();
    private let adminPrincipal: Text = "xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxx";
    
    system func preupgrade() {
        _canistergeekMonitorUD := ? canistergeekMonitor.preupgrade();
    };

    system func postupgrade() { 
        canistergeekMonitor.postupgrade(_canistergeekMonitorUD);
        _canistergeekMonitorUD := null;
    };
    
    public query ({caller}) func getCanisterMetrics(parameters: Canistergeek.GetMetricsParameters): async ?Canistergeek.CanisterMetrics {
        validateCaller(caller);
        canistergeekMonitor.getMetrics(parameters);
    };

    public shared ({caller}) func collectCanisterMetrics(): async () {
        validateCaller(caller);
        canistergeekMonitor.collectMetrics();
    };
    
    private func validateCaller(principal: Principal) : () {
        //data is available only for specific principal
        if (not (Principal.toText(principal) == adminPrincipal)) {
            Prelude.unreachable();
        }
    };
    
    public shared ({caller}) func doThis(): async () {
        canistergeekMonitor.collectMetrics();
        // rest part of the your method...
    };
    
    public shared ({caller}) func doThat(): async () {
        canistergeekMonitor.collectMetrics();
        // rest part of the your method...
    };
    
    public query ({caller}) func getThis(): async Text {
        "this";
    };
    
    public query ({caller}) func getThat(): async Text {
        "that";
    };
    
}
```