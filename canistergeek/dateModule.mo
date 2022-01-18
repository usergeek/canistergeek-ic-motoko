import Array "mo:base/Array";
import Int "mo:base/Int";
import Int16 "mo:base/Int16";
import Int32 "mo:base/Int32";
import Iter "mo:base/Iter";
import Nat16 "mo:base/Nat16";
import Option "mo:base/Option";
import Text "mo:base/Text";
import Time "mo:base/Time";

import UtilsModule "utilsModule";
import ChronosphereDate "chronosphereDate";

module {

    private module Constants {
        public let ONE_DAY_NANOS : Nat = 86_400_000_000_000;
        public let ONE_DAY_SECONDS : Nat = 86_400;
        public let ONE_SECOND_NANOS : Nat = 1_000_000_000;
    };

    public module ISO8601 {

        public type DatePartsISO8601 = (Nat, Nat, Nat); //(year, month, day)
        public type DateTimePartsISO8601 = (Nat, Nat, Nat, Nat, Nat, Nat); //(year, month, day, hour, minute, second)

    };

    public module Calendar {

        public class Calendar() {
            var year : Nat = 0;
            var month : Nat = 0;
            var day : Nat = 0;
            var timeNanoseconds : Int = Time.now();

            public func updateTime(time: Int) : () { 
                timeNanoseconds := time;
                let dateParts: ?ISO8601.DatePartsISO8601 = Date.toDatePartsISO8601(timeNanoseconds);
                switch(dateParts) {
                    case (null) {};
                    case (?(dateYear : Nat, dateMonth : Nat, dateDay : Nat)) {
                        year := dateYear;
                        month := dateMonth;
                        day := dateDay;
                    };
                };
            };

            updateTime(timeNanoseconds);

            public func getTime() : Int { timeNanoseconds };

            public func addDays(days: Int) : () {
                let newTimeNanoseconds : Int = timeNanoseconds + days * Constants.ONE_DAY_NANOS;
                updateTime(newTimeNanoseconds);
            };

            public func nextDay() : () {
                let maxDay = Date.getNumberOfDaysInMonth(year, month);
                if(day < maxDay) {
                    day := day + 1;
                } else {
                    day := 1;
                    if(month < 12) {
                        month := month + 1;
                    } else {
                        month := 1;
                        year := year + 1;
                    }
                };
                timeNanoseconds := timeNanoseconds + Constants.ONE_DAY_NANOS;
            };

            public func prevDay() : () {
                if(day > 1) {
                    day := day - 1;
                } else {
                    if(month > 1) {
                        month := month - 1;
                        day := Date.getNumberOfDaysInMonth(year, month);
                    } else {
                        month := 12;
                        year := year - 1;
                        day := Date.getNumberOfDaysInMonth(year, month);
                    }
                };
                timeNanoseconds := timeNanoseconds - Constants.ONE_DAY_NANOS;
            };

            public func getISO8601DateParts() : (Nat, Nat, Nat) {
                return (year, month, day);
            };
        };

        public func getPreviousMonth(year: Nat, month: Nat) : (Nat, Nat) {
            if(month > 1) {
                (year, month - 1);
            } else {
                (year - 1, 12);
            };
        };

        public func getNextMonth(year: Nat, month: Nat) : (Nat, Nat) {
            if(month < 12) {
                (year, month + 1);
            } else {
                (year + 1, 1);
            };
        };

        public func appendDays((year, month, day): (Nat, Nat, Nat), days : Int16) : (Nat, Nat, Nat) {
            if(days > 0) {
                let maxDays : Nat = Date.getNumberOfDaysInMonth(year, month); 
                let daysLeft : Int16 = Int16.fromNat16(Nat16.fromNat(maxDays - day)); 
                if(days <= daysLeft) {
                    return (year, month, day + Nat16.toNat(Int16.toNat16(days)));
                } else {
                    let (nextYear, nextMonth) : (Nat, Nat) = getNextMonth(year, month);
                    return appendDays((nextYear, nextMonth, 1), days - daysLeft - 1);
                }
            } else if (days < 0) {
                if(Int.abs(Int16.toInt(days)) < day) {
                    return (year, month, day - Int.abs(Int16.toInt(days)));
                } else {
                    let (previousYear, previousMonth) : (Nat, Nat) = getPreviousMonth(year, month);
                    let maxDays = Date.getNumberOfDaysInMonth(previousYear, previousMonth); 
                    return appendDays((previousYear, previousMonth, maxDays), days + Int16.fromNat16(Nat16.fromNat(day)));
                }
            } else {
                return (year, month, day);
            }
        };
    };

    public module Date {
        
        public func nowToDatePartsISO8601() : ?ISO8601.DatePartsISO8601 {
            return toDatePartsISO8601(Time.now());
        }; 
 
        public func nowToDateTimePartsISO8601() : ?ISO8601.DateTimePartsISO8601 {
            return toDateTimePartsISO8601(Time.now());
        };

        public func toDatePartsISO8601(time: Int) : ?ISO8601.DatePartsISO8601 {
            let date : ChronosphereDate.Date = toDate(time);
            let dateParts: ChronosphereDate.DateParts = ChronosphereDate.unpack(date);
            let #Year year = dateParts.year;
            let monthNumeral: Int = ChronosphereDate.monthNumeral(dateParts.month);
            let #Day dayNumeral = dateParts.day;
            if (year < 0 or monthNumeral < 0 or dayNumeral < 0) {
                return null
            };
            return ?(UtilsModule.intToNat(year), UtilsModule.intToNat(monthNumeral), UtilsModule.intToNat(dayNumeral));
        };
  
        public func toDateTimePartsISO8601(time: Int) : ?ISO8601.DateTimePartsISO8601 {
            let dateBase : ChronosphereDate.Date = toDate(time);
            let dateParts: ChronosphereDate.DateParts = ChronosphereDate.unpack(dateBase);

            let #Year year = dateParts.year;
            let monthNumeral: Int = ChronosphereDate.monthNumeral(dateParts.month);
            let #Day dayNumeral = dateParts.day;

            let dateTimeBase : ChronosphereDate.DateTime = toDateTime(time);
            let dateTimeParts: ChronosphereDate.DateTimeParts = ChronosphereDate.unpackTime(dateTimeBase);

            let #Hour hours = dateTimeParts.hours;
            let #Minute minutes = dateTimeParts.minutes;
            let #Second seconds = dateTimeParts.seconds;
 
            if (year < 0 or monthNumeral < 0 or dayNumeral < 0 or hours < 0 or minutes < 0 or seconds < 0 ) {
                return null;
            };
            return ?(UtilsModule.intToNat(year), UtilsModule.intToNat(monthNumeral), UtilsModule.intToNat(dayNumeral), UtilsModule.intToNat(hours), UtilsModule.intToNat(minutes), UtilsModule.intToNat(seconds));
        };

        public func datePartsISO8601ToTime(dateParts: ISO8601.DatePartsISO8601): ?Int {
            let (years, months, days): ISO8601.DatePartsISO8601 = dateParts;
            let month: ?ChronosphereDate.Month = ChronosphereDate.monthNumeralToMonth(months);
            switch(month) {
                case (null) { null; };
                case (?monthValue) {
                    let daysSinceEpoch: Int = ChronosphereDate.epochToDate(#Year (years), monthValue, #Day (days));
                    let timeNanos: Int = daysSinceEpoch * Constants.ONE_DAY_NANOS;
                    ?timeNanos;
                };
            };
        };

        public func dateTimePartsISO8601ToTime(dateTimeParts: ISO8601.DateTimePartsISO8601): ?Int {
            let (years, months, days, hours, minutes, seconds): ISO8601.DateTimePartsISO8601 = dateTimeParts;
            let month: ?ChronosphereDate.Month = ChronosphereDate.monthNumeralToMonth(months);
            switch(month) {
                case (null) { null; };
                case (?monthValue) {
                    let daysSinceEpoch: Int = ChronosphereDate.epochToDate(#Year (years), monthValue, #Day (days));
                    let daysSinceEpochToSeconds = daysSinceEpoch * Constants.ONE_DAY_SECONDS;
                    let hoursInSeconds = hours * 60 * 60;
                    let minutesInSeconds = minutes * 60;
                    let timeNanos: Int = (daysSinceEpochToSeconds + hoursInSeconds + minutesInSeconds + seconds) * Constants.ONE_SECOND_NANOS;
                    ?timeNanos;
                };
            };
        };

        public func secondsFromDayStart(time: Int) : ?Nat {
            let dateTime : ChronosphereDate.DateTime = toDateTime(time);
            let #DateTime dateTimeBase = dateTime;
            let result = Int32.toInt(dateTimeBase);
            if (result < 0) {
                return null;
            };
            return ?UtilsModule.intToNat(result);
        };

        public func getNumberOfDaysInMonth(year: Nat, month: Nat) : Nat {
            let yearVariant: ChronosphereDate.Year = #Year year;
            if (ChronosphereDate.isLeapYear(yearVariant)) {
                switch(month) {
                    case 1 { 31 };
                    case 2 { 29 };
                    case 3 { 31 };
                    case 4 { 30 };
                    case 5 { 31 };
                    case 6 { 30 };
                    case 7 { 31 };
                    case 8 { 31 };
                    case 9 { 30 };
                    case 10 { 31 };
                    case 11 { 30 };
                    case 12 { 31 };
                    case _ { 0 };
                };
            } else {
                switch(month) {
                    case 1 { 31 };
                    case 2 { 28 };
                    case 3 { 31 };
                    case 4 { 30 };
                    case 5 { 31 };
                    case 6 { 30 };
                    case 7 { 31 };
                    case 8 { 31 };
                    case 9 { 30 };
                    case 10 { 31 };
                    case 11 { 30 };
                    case 12 { 31 };
                    case _ { 0 };
                }
            }
        };

        //Private

        private func toDate(time: Int): ChronosphereDate.Date {
            let base = Int32.fromInt(time / (24 * 60 * 60 * Constants.ONE_SECOND_NANOS));
            let date : ChronosphereDate.Date = #Date base;
        };

        private func toDateTime(time: Int): ChronosphereDate.DateTime {
            let timeToSeconds: Int = time / Constants.ONE_SECOND_NANOS;
            let timeBase: Int = timeToSeconds % (24 * 60 * 60);
            let base: Int32 = Int32.fromInt(timeBase);
            let date : ChronosphereDate.DateTime = #DateTime base;
        };

    };

    

};

