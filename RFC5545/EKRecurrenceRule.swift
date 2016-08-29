//
//  EKRecurrenceRule.swift
//
//  Copyright © 2016 Gargoyle Software, LLC.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation
import EventKit

/**
 * Splits the input string by comma and returns an array of all values which are less than the
 * constraint value.
 *
 * - Parameter lessThan: The value that the numbers must be less than.
 * - Parameter csv: The comma separated input data.
 *
 * - Throws: `RFC5545Exception.InvalidRecurrenceRule`
 *
 * - Returns: An array of `Int`
 */
private func allValues(lessThan lessThan: Int, csv: String) throws -> [Int] {
    var ret: [Int] = []

    for dayNum in csv.componentsSeparatedByString(",") {
        guard let num = Int(dayNum) where abs(num) < lessThan else {
            throw RFC5545Exception.InvalidRecurrenceRule
        }

        ret.append(num)
    }

    return ret
}

extension EKRecurrenceRule {
    /// Converts the recurrence rule into an RFC5545 compatible format.
    //
    /// - Returns: The generated RFC5545 RRULE string.
    //
    /// - SeeAlso: [RFC5545 RRULE](https://tools.ietf.org/html/rfc5545#section-3.8.5.3)
    func rfc5545() -> String {
        let freq: String
        switch frequency {
        case .Daily:
            freq = "DAILY"
        case .Monthly:
            freq = "MONTHLY"
        case .Weekly:
            freq = "WEEKLY"
        case .Yearly:
            freq = "YEARLY"
        }

        var text = "RRULE:FREQ=\(freq)"

        if interval > 1 {
            text += ";INTERVAL=\(interval)"
        }

        if firstDayOfTheWeek > 0 {
            let days = ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"]
            text += ";WKST=" + days[firstDayOfTheWeek]
        }

        if let end = recurrenceEnd {
            if let date = end.endDate {
                // TODO: According the the RFC doc, "should be specified as a date with local
                // time and time zone"...so this should change from .utc to something else.  That
                // means we are going to need a new enum value so specify a local time
                text += ";UNTIL=\(date.rfc5545(format: .utc))"
            } else {
                text += ";COUNT=\(end.occurrenceCount)"
            }
        }

        return text
    }

    /**
     * Parse an RFC5545 RRULE specification and return an `EKRecurrenceRule`
     *
     * - Parameter rrule: The RFC5545 block representing an RRULE.
     *
     * - Throws: An `RFC5545Exception` if something goes wrong.
     *
     * - Returns: An `EKRecurrenceRule`
     *
     * - SeeAlso: [RFC5545 RRULE](https://tools.ietf.org/html/rfc5545#section-3.8.5.3)
     * - SeeAlso: [RFC5545 RECUR](https://tools.ietf.org/html/rfc5545#section-3.3.10)
     */
    convenience init(rrule: String) throws {
        // Make sure it's not just the RRULE: part
        guard rrule.characters.count > 6 else { throw RFC5545Exception.InvalidRecurrenceRule }

        var foundUntilOrCount = false
        var frequency: EKRecurrenceFrequency?
        var endDate: NSDate?
        var count: Int?
        var interval: Int?
        var daysOfTheWeek: [EKRecurrenceDayOfWeek]?
        var daysOfTheMonth: [Int]?
        var weeksOfTheYear: [Int]?
        var monthsOfTheYear: [Int]?
        var daysOfTheYear: [Int]?
        var positions: [Int]?

        let index = rrule.startIndex.advancedBy(6)
        for part in rrule.substringFromIndex(index).componentsSeparatedByString(";") {
            let pair = part.componentsSeparatedByString("=")
            guard pair.count == 2 else { throw RFC5545Exception.InvalidRecurrenceRule }

            let key = pair[0].uppercaseString

            if key.hasPrefix("X-") {
                // TODO: Save all of these somewhere
                continue
            }

            let value = pair[1]

            switch key {
                case "FREQ":
                    guard frequency == nil else { throw RFC5545Exception.InvalidRecurrenceRule }

                    switch value {
                    case "DAILY": frequency = .Daily
                    case "MONTHLY": frequency = .Monthly
                    case "WEEKLY": frequency = .Weekly
                    case "YEARLY": frequency = .Yearly
                    case "SECONDLY", "MINUTELY", "HOURLY": break
                    default: throw RFC5545Exception.InvalidRecurrenceRule
                }

            case "UNTIL":
                guard foundUntilOrCount == false else { throw RFC5545Exception.InvalidRecurrenceRule }

                do {
                    let dateInfo = try parseDateString(value)
                    endDate = dateInfo.date
                } catch {
                    // The UNITL keyword is allowed to be just a date, without the normal VALUE=DATE specifier....sigh.
                    var year = 0
                    var month = 0
                    var day = 0

                    var args: [CVarArgType] = []

                    withUnsafeMutablePointers(&year, &month, &day) {
                        y, m, d in
                        args.append(y)
                        args.append(m)
                        args.append(d)
                    }

                    if vsscanf(value, "%4d%2d%2d", getVaList(args)) == 3 {
                        let components = NSDateComponents()
                        components.year = year
                        components.month = month
                        components.day = day

                        // This is bad, because we don't know the timezone...
                        endDate = NSCalendar.currentCalendar().dateFromComponents(components)!
                    }
                }

                if endDate == nil {
                    throw RFC5545Exception.InvalidRecurrenceRule
                }
                
                foundUntilOrCount = true

            case "COUNT":
                guard foundUntilOrCount == false, let ival = Int(value) else { throw RFC5545Exception.InvalidRecurrenceRule }
                count = ival

                foundUntilOrCount = true

            case "INTERVAL":
                guard interval == nil, let ival = Int(value) else { throw RFC5545Exception.InvalidRecurrenceRule }
                interval = ival

            case "BYDAY":
                guard daysOfTheWeek == nil else { throw RFC5545Exception.InvalidRecurrenceRule }

                daysOfTheWeek = []

                let weekday: [String : EKWeekday] = [
                    "SU" : .Sunday,
                    "MO" : .Monday,
                    "TU" : .Tuesday,
                    "WE" : .Wednesday,
                    "TH" : .Thursday,
                    "FR" : .Friday,
                    "SA" : .Saturday
                ]

                for day in value.componentsSeparatedByString(",") {
                    let dayStr: String
                    var num = 0

                    if day.characters.count > 2 {
                        let index = day.endIndex.advancedBy(-2)
                        dayStr = day.substringFromIndex(index)
                        num = Int(day.substringToIndex(index)) ?? 0
                    } else {
                        dayStr = day
                    }

                    if let day = weekday[dayStr] {
                        daysOfTheWeek!.append(EKRecurrenceDayOfWeek(day, weekNumber: num))
                    }
                }

            case "BYMONTHDAY":
                guard daysOfTheMonth == nil else { throw RFC5545Exception.InvalidRecurrenceRule }
                daysOfTheMonth = try allValues(lessThan: 32, csv: value)

            case "BYYEARDAY":
                guard daysOfTheYear == nil else { throw RFC5545Exception.InvalidRecurrenceRule }
                daysOfTheYear = try allValues(lessThan: 367, csv: value)

            case "BYWEEKNO":
                guard weeksOfTheYear == nil else { throw RFC5545Exception.InvalidRecurrenceRule }
                weeksOfTheYear = try allValues(lessThan: 54, csv: value)

            case "BYMONTH":
                guard monthsOfTheYear == nil else { throw RFC5545Exception.InvalidRecurrenceRule }
                monthsOfTheYear = try allValues(lessThan: 13, csv: value)

            case "BYSETPOS":
                guard positions == nil else { throw RFC5545Exception.InvalidRecurrenceRule }
                positions = try allValues(lessThan: 367, csv: value)

            default:
                throw RFC5545Exception.UnsupportedRecurrenceProperty
            }
        }

        guard let freq = frequency else { throw RFC5545Exception.InvalidRecurrenceRule }

        // The BYDAY rule part MUST NOT be specified with a numeric value when the FREQ rule part is
        // not set to MONTHLY or YEARLY.
        if let daysOfTheWeek = daysOfTheWeek where freq != .Monthly && freq != .Yearly {
            for day in daysOfTheWeek {
                if day.weekNumber != 0 {
                    throw RFC5545Exception.InvalidRecurrenceRule
                }
            }
        }

        // The BYMONTHDAY rule part MUST NOT be specified when the FREQ rule part is set to WEEKLY.
        if daysOfTheMonth != nil && freq == .Weekly {
            throw RFC5545Exception.InvalidRecurrenceRule
        }

        // The BYYEARDAY rule part MUST NOT be specified when the FREQ rule part is set to DAILY, WEEKLY, or MONTHLY.
        if daysOfTheYear != nil && (freq == .Daily || freq == .Weekly || freq == .Monthly) {
            throw RFC5545Exception.InvalidRecurrenceRule
        }

        // BYWEEKNO MUST NOT be used when the FREQ rule part is set to anything other than YEARLY
        if weeksOfTheYear != nil && freq != .Yearly {
            throw RFC5545Exception.InvalidRecurrenceRule
        }

        let nonPositionAllNil = daysOfTheYear == nil && daysOfTheMonth == nil && daysOfTheWeek == nil && weeksOfTheYear == nil && monthsOfTheYear == nil

        // If BYSETPOS is used, one of the other BY* rules must be used as well
        if positions != nil && nonPositionAllNil {
            throw RFC5545Exception.InvalidRecurrenceRule
        }

        let end: EKRecurrenceEnd?
        if let endDate = endDate {
            end = EKRecurrenceEnd(endDate: endDate)
        } else if let count = count {
            end = EKRecurrenceEnd(occurrenceCount: count)
        } else {
            end = nil
        }


        if nonPositionAllNil && positions == nil {
            self.init(recurrenceWithFrequency: freq, interval: interval ?? 1, end: end)
        } else {
            // TODO: This needs to handle multiple BY* rules as defined by the RFC spec.  Maybe the EKRecurrenceRule
            // constructor does it for us, but it needs to be tested.
            self.init(recurrenceWithFrequency: freq, interval: interval ?? 1, daysOfTheWeek: daysOfTheWeek, daysOfTheMonth: daysOfTheMonth, monthsOfTheYear: monthsOfTheYear, weeksOfTheYear: weeksOfTheYear, daysOfTheYear: daysOfTheYear, setPositions: positions, end: end)
        }
    }
}









































