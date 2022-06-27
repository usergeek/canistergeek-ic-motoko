# Canistergeek-IC-Motoko

Canistergeek-IC-Motoko is the open-source tool for Internet Computer to track your project canisters cycles and memory status and collect log messages.

Canistergeek-IC-Motoko can be integrated into your canisters as motoko library which exposes following components:
- `Monitor` - public class that collects the data for specific canister by 5 minutes intervals.
- `Logger` - public class that collects log messages for specific canister.

Canistergeek-IC-Motoko should be used together with [Canistergeek-IC-JS](https://github.com/usergeek/canistergeek-ic-js) - Javascript library that fetches the data from canisters, performs all necessary calculations and displays it on a webpage 

#### Memory consumption

- `Monitor` - stored data for cycles and memory consumes ~6.5Mb per year per canister (assuming data points every 5 minutes).
- `Logger` - depends on the length of messages and their number. (canister with e.g. 10000 messages with 4096 characters each consumes 120Mb after upgrade).

## Metrics

### Collecting the data

Data can be collected in two ways: automatically and manually

1. Manually by calling `collectCanisterMetrics` public method of your canister.
2. Automatically by calling `canistergeekMonitor.collectMetrics();` in "update" methods in your canister to guarantee desired "Collect metrics" frequency. In some cases you may want to collect metrics in every "update" method to get the full picture in realtime and see how "update" methods influence canister price and capacity.

#### Update calls

Monitor collects the number of canister update calls

#### Cycles

Monitor collects how many cycles left at particular time using `ExperimentalCycles.balance()`.

#### Memory

Monitor collects how many memory bytes the canister consumes at particular time using `Prim.rts_memory_size()`.

#### Heap Memory

Monitor collects how many heap memory bytes the canister consumes at particular time using `Prim.rts_heap_size()`.

## Logger

### Collecting log messages

Log messages can be collected by calling `canistergeekLogger.logMessage(msg: Text)` method in "update" methods in your canister.

#### Log messages

Logger collects time/message pairs with a maximum message length of 4096 characters.

Default number of messages (10000) can be overridden with corresponding method in realtime.

## Installation

### Option 1: Vessel

Vessel is a package manager for Motoko. [Learn more](https://github.com/dfinity/vessel#getting-started).

- Add canistergeek to your `package-set.dhall`:

```dhall
let
  additions =
      [{ name = "canistergeek"
      , repo = "https://github.com/usergeek/canistergeek-ic-motoko"
      , version = "v0.0.4"
      , dependencies = ["base"] : List Text
      }] : List Package
```

- Add canistergeek to your `vessel.dhall`:

```dhall
dependencies = [ ..., "canistergeek" ],
```

- Import library in your canister

```motoko
import Canistergeek "mo:canistergeek/canistergeek";
```



### Option 2: Copy Paste

- Copy `src` folder from this repository into your project, renaming it to `canistergeek`.
- Import library in your canister

```motoko
import Canistergeek "../canistergeek/canistergeek";
```

## Usage

### Monitor

Please perform the following steps

#### Initialize the monitor

Initialize Canistergeek Monitor as a private constant.

```motoko
actor {

    private let canistergeekMonitor = Canistergeek.Monitor();

}
```

#### Add post/pre upgrade monitor hooks

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

### Logger

Please perform the following steps

#### Initialize the logger

Initialize Canistergeek Logger as a private constant.

```motoko
actor {

    private let canistergeekLogger = Canistergeek.Logger();

}
```

#### Add post/pre upgrade logger hooks

Add stable variable and implement pre/post upgrade hooks.
This step is necessary to save collected log messages between canister upgrades.

```motoko
actor {
    
    stable var _canistergeekLoggerUD: ? Canistergeek.LoggerUpgradeData = null;
    
    system func preupgrade() {
        _canistergeekLoggerUD := ? canistergeekLogger.preupgrade();
    };

    system func postupgrade() { 
        canistergeekLogger.postupgrade(_canistergeekLoggerUD);
        _canistergeekLoggerUD := null;
        
        //Optional: override default number of log messages to your value
        canistergeekLogger.setMaxMessagesCount(3000);
    };
    
}
```

#### Implement public methods

Implement public methods in the canister in order to query collected log messages

```motoko
actor {
    
    // CANISTER LOGGER

    /**
    * Returns collected log messages based on passed parameters.
    * Called from browser.
    */
    public query ({caller}) func getCanisterLog(request: ?Canistergeek.CanisterLogRequest) : async ?Canistergeek.CanisterLogResponse {
        validateCaller(caller);
        canistergeekLogger.getLog(request);
    };
    
    private func validateCaller(principal: Principal) : () {
        //limit access here!
    };
    
}
```

#### Adjust "update" methods

Call `canistergeekLogger.logMessage()` method where you want to log a message.

```motoko
actor {
    
    public shared ({caller}) func doThis(): async () {
        canistergeekLogger.logMessage("doThis");
        // rest part of the your method...
    };
    
    public shared ({caller}) func doThat(): async () {
        canistergeekLogger.logMessage("doThat");
        // rest part of the your method...
    };
    
}
```

## LIMIT ACCESS TO YOUR DATA

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
import Time "mo:base/Time";
import Canistergeek "../canistergeek/canistergeek";

actor {

    stable var _canistergeekMonitorUD: ? Canistergeek.UpgradeData = null;
    private let canistergeekMonitor = Canistergeek.Monitor();
    
    stable var _canistergeekLoggerUD: ? Canistergeek.LoggerUpgradeData = null;
    private let canistergeekLogger = Canistergeek.Logger();
    
    private let adminPrincipal: Text = "xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxx";
    
    system func preupgrade() {
        _canistergeekMonitorUD := ? canistergeekMonitor.preupgrade();
        _canistergeekLoggerUD := ? canistergeekLogger.preupgrade();
    };

    system func postupgrade() { 
        canistergeekMonitor.postupgrade(_canistergeekMonitorUD);
        _canistergeekMonitorUD := null;
        
        canistergeekLogger.postupgrade(_canistergeekLoggerUD);
        _canistergeekLoggerUD := null;
        canistergeekLogger.setMaxMessagesCount(3000);
        
        canistergeekLogger.logMessage("postupgrade");
    };
    
    public query ({caller}) func getCanisterMetrics(parameters: Canistergeek.GetMetricsParameters): async ?Canistergeek.CanisterMetrics {
        validateCaller(caller);
        canistergeekMonitor.getMetrics(parameters);
    };

    public shared ({caller}) func collectCanisterMetrics(): async () {
        validateCaller(caller);
        canistergeekMonitor.collectMetrics();
    };
    
    public query ({caller}) func getCanisterLog(request: ?Canistergeek.CanisterLogRequest) : async ?Canistergeek.CanisterLogResponse {
        validateCaller(caller);
        return canistergeekLogger.getLog(request);
    };
    
    private func validateCaller(principal: Principal) : () {
        //data is available only for specific principal
        if (not (Principal.toText(principal) == adminPrincipal)) {
            Prelude.unreachable();
        }
    };
    
    public shared ({caller}) func doThis(): async () {
        canistergeekMonitor.collectMetrics();
        canistergeekLogger.logMessage("doThis");
        // rest part of the your method...
    };
    
    public shared ({caller}) func doThat(): async () {
        canistergeekMonitor.collectMetrics();
        canistergeekLogger.logMessage("doThat");
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
