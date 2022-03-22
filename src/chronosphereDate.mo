/*
    Based on https://github.com/enzoh/chronosphere
*/

/*
    Copyright 2021 Enzo Haussecker Licensed under the Apache License, Version 2.0 (the «License»);
*/

/*
Copyright 2021 Enzo Haussecker

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
*/

import Int32 "mo:base/Int32";
import Time "mo:base/Time";

module ChronosphereDate {
        
    public type Year = {
        #Year : Int;
    };

    public type Month = {
        #January;
        #February;
        #March;
        #April;
        #May;
        #June;
        #July;
        #August;
        #September;
        #October;
        #November;
        #December;
    };

    public func monthNumeralToMonth(monthNumeral : Nat) : ?Month {
        switch (monthNumeral) {
            case (1) ?#January;
            case (2) ?#February;
            case (3) ?#March;
            case (4) ?#April;
            case (5) ?#May;
            case (6) ?#June;
            case (7) ?#July;
            case (8) ?#August;
            case (9) ?#September;
            case (10) ?#October;
            case (11) ?#November;
            case (12) ?#December;
            case (_) null;
        } 
    };

    public func monthNumeral(month : Month) : Int {
        switch (month) {
            case (#January) 1;
            case (#February) 2;
            case (#March) 3;
            case (#April) 4;
            case (#May) 5;
            case (#June) 6;
            case (#July) 7;
            case (#August) 8;
            case (#September) 9;
            case (#October) 10;
            case (#November) 11;
            case (#December) 12;
        }
    };

    public type Day = {
        #Day : Int;
    };

    public type DayOfWeek = {
        #Sunday;
        #Monday;
        #Tuesday;
        #Wednesday;
        #Thursday;
        #Friday;
        #Saturday;
    };

    public func dayOfWeekNumeralISO8601(wday : DayOfWeek) : Int {
        switch (wday) {
            case (#Sunday) 7;
            case (#Monday) 1;
            case (#Tuesday) 2;
            case (#Wednesday) 3;
            case (#Thursday) 4;
            case (#Friday) 5;
            case (#Saturday) 6;
        }
    };

    public type Hour = {
        #Hour : Int;
    };

    public type Minute = {
        #Minute : Int;
    };
    
    public type Second = {
        #Second : Int;
    };

    public type DateParts = {
        year : Year;
        month : Month;
        day : Day;
        wday : DayOfWeek;
    };

    public type DateTimeParts = {
        hours : Hour;
        minutes : Minute;
        seconds : Second;
    };
    
    public type Date = {
        #Date : Int32;
    };

    public type DateTime = {
        #DateTime : Int32;
    };

    public func create(year : Year, month : Month, day : Day) : ? Date {
        let days = epochToDate(year, month, day);
        if (0 <= days and days <= 2932896) {// "January 1, 1970" - "December 31, 9999"
            let base = Int32.fromInt(days);
            ? #Date base
        } else {
            null
        }
    };

    public func now() : Date {
        let base = Int32.fromInt(Time.now() / 86400000000000);
        #Date base
    };

    public func pack(parts : DateParts) : ? Date {
        create(parts.year, parts.month, parts.day)
    };

    public func unpackTime(#DateTime base : DateTime) : DateTimeParts {
        let baseValue = Int32.toInt(base);
        var hours: Int = baseValue / 3600;
        var minutes: Int = (baseValue % 3600) / 60; 
        var seconds: Int = baseValue % 60;
        return { 
            hours = #Hour hours;
            minutes = #Minute minutes;
            seconds = #Second seconds;
        }
    };

    public func unpack(#Date base : Date) : DateParts {
        var year = 1970;
        var days = Int32.toInt(base);
        var leap = false;
        var size = 365;
        while (days >= size) {
            year += 1;
            days -= size;
        leap := isLeapYear(#Year year);
            size := if leap 366 else 365;
        };
        let (month, day) = if (leap) {
            if (days > 181) {
                if (days > 273) {
                    if (days > 334) {
                        (#December, days - 334)
                    } else if (days > 304) {
                        (#November, days - 304)
                    } else {
                        (#October, days - 273)
                    }
                } else if (days > 243) {
                    (#September, days - 243)
                } else if (days > 212) {
                    (#August, days - 212)
                } else {
                    (#July, days - 181)
                }
            } else if (days > 90) {
                if (days > 151) {
                    (#June, days - 151)
                } else if (days > 120) {
                    (#May, days - 120)
                } else {
                    (#April, days - 90)
                }
            } else if (days > 59) {
                (#March, days - 59)
            } else if (days > 30) {
                (#February, days - 30)
            } else {
                (#January, days + 1)
            }
        } else if (days > 180) {
            if (days > 272) {
                if (days > 333) {
                (#December, days - 333)
                } else if (days > 303) {
                (#November, days - 303)
                } else {
                (#October, days - 272)
                }
            } else if (days > 242) {
                (#September, days - 242)
            } else if (days > 211) {
                (#August, days - 211)
            } else {
                (#July, days - 180)
            }
        } else if (days > 89) {
            if (days > 150) {
                (#June, days - 150)
            } else if (days > 119) {
                (#May, days - 119)
            } else {
                (#April, days - 89)
            }
        } else if (days > 58) {
            (#March, days - 58)
        } else if (days > 30) {
            (#February, days - 30)
        } else {
            (#January, days + 1)
        };
        let wday = switch (1 + (Int32.toInt(base) + 4) % 7) {
            case 1 #Sunday;
            case 2 #Monday;
            case 3 #Tuesday;
            case 4 #Wednesday;
            case 5 #Thursday;
            case 6 #Friday;
            case _ #Saturday;
        };
        {
            year = #Year year;
            month = month;
            day = #Day day;
            wday = wday;
        }
    };

    public func isLeapYear(year : Year) : Bool {
        let #Year y = year;
        y % 400 == 0 or y % 100 != 0 and y % 4 == 0
    };

    public func epochToDate(year : Year, month : Month, day : Day) : Int {
        let leap = isLeapYear(year);
        epochToYear(year) + yearToMonth(leap, month) + monthToDay(day) - 1
    };

    private func epochToYear(year : Year) : Int {
        let #Year y = year;
        365 * (y - 1970) + (y - 1969) / 4 - (y - 1901) / 100 + (y - 1601) / 400
    };

    private func yearToMonth(leap : Bool, month : Month) : Int {
        if (leap) {
        switch (month) {
            case (#January) 0;
            case (#February) 31;
            case (#March) 60;
            case (#April) 91;
            case (#May) 121;
            case (#June) 152;
            case (#July) 182;
            case (#August) 213;
            case (#September) 244;
            case (#October) 274;
            case (#November) 305;
            case (#December) 335;
        }
        } else {
        switch (month) {
            case (#January) 0;
            case (#February) 31;
            case (#March) 59;
            case (#April) 90;
            case (#May) 120;
            case (#June) 151;
            case (#July) 181;
            case (#August) 212;
            case (#September) 243;
            case (#October) 273;
            case (#November) 304;
            case (#December) 334;
        }
        }
    };

    private func monthToDay(day : Day) : Int {
        let #Day d = day;
        d
    };
};