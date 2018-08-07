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
private func allValues(lessThan: Int, csv: String) throws -> [Int] {
    var ret: [Int] = []

    for dayNum in csv.components(separatedBy: ",") {
        guard let num = Int(dayNum) , abs(num) < lessThan else {
            throw RFC5545Exception.invalidRecurrenceRule
        }

        ret.append(num)
    }

    return ret
}

extension EKRecurrenceRule {
    /**
     *  Converts the recurrence rule into an RFC5545 compatible format.
     *
     *  - Returns: The generated RFC5545 RRULE string.
     *
     * - SeeAlso: [RFC5545 RRULE](https://tools.ietf.org/html/rfc5545#section-3.8.5.3)
     * - SeeAlso: [RFC5545 RECUR](https://tools.ietf.org/html/rfc5545#section-3.3.10)
     */
    func rfc5545() -> String {
        let freq: String
        switch frequency {
        case .daily:
            freq = "DAILY"
        case .monthly:
            freq = "MONTHLY"
        case .weekly:
            freq = "WEEKLY"
        case .yearly:
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
                /*
                 TODO:  Implement this timezone stuff from the RFC spec:
                 
                 The UNTIL rule part defines a DATE or DATE-TIME value that bounds
                 the recurrence rule in an inclusive manner.  If the value
                 specified by UNTIL is synchronized with the specified recurrence,
                 this DATE or DATE-TIME becomes the last instance of the
                 recurrence.  The value of the UNTIL rule part MUST have the same
                 value type as the "DTSTART" property.  Furthermore, if the
                 "DTSTART" property is specified as a date with local time, then
                 the UNTIL rule part MUST also be specified as a date with local
                 time.  If the "DTSTART" property is specified as a date with UTC
                 time or a date with local time and time zone reference, then the
                 UNTIL rule part MUST be specified as a date with UTC time.  In the
                 case of the "STANDARD" and "DAYLIGHT" sub-components the UNTIL
                 rule part MUST always be specified as a date with UTC time.  If
                 specified as a DATE-TIME value, then it MUST be specified in a UTC
                 time format.  If not present, and the COUNT rule part is also not
                 present, the "RRULE" is considered to repeat forever.
                 */
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
        guard rrule.count > 6 else { throw RFC5545Exception.invalidRecurrenceRule }

        var foundUntilOrCount = false
        var frequency: EKRecurrenceFrequency?
        var endDate: Date?
        var count: Int?
        var interval: Int?
        var daysOfTheWeek: [EKRecurrenceDayOfWeek]?
        var daysOfTheMonth: [Int]?
        var weeksOfTheYear: [Int]?
        var monthsOfTheYear: [Int]?
        var daysOfTheYear: [Int]?
        var positions: [Int]?

        let index = rrule.index(rrule.startIndex, offsetBy: 6)
        for part in String(rrule[index...]).components(separatedBy: ";") {
            let pair = part.components(separatedBy: "=")
            guard pair.count == 2 else { throw RFC5545Exception.invalidRecurrenceRule }

            let key = pair[0].uppercased()

            if key.hasPrefix("X-") {
                // TODO: Save all of these somewhere
                continue
            }

            let value = pair[1]

            switch key {
                case "FREQ":
                    guard frequency == nil else { throw RFC5545Exception.invalidRecurrenceRule }

                    switch value {
                    case "DAILY": frequency = .daily
                    case "MONTHLY": frequency = .monthly
                    case "WEEKLY": frequency = .weekly
                    case "YEARLY": frequency = .yearly
                    case "SECONDLY", "MINUTELY", "HOURLY": break
                    default: throw RFC5545Exception.invalidRecurrenceRule
                }

            case "UNTIL":
                guard foundUntilOrCount == false else { throw RFC5545Exception.invalidRecurrenceRule }

                do {
                    let dateInfo = try parseDateString(value)
                    endDate = dateInfo.date
                } catch {
                    // The UNITL keyword is allowed to be just a date, without the normal VALUE=DATE specifier....sigh.
                    var year = 0
                    var month = 0
                    var day = 0

                    var args: [CVarArg] = []

                    withUnsafeMutablePointer(to: &year) {
                        y in
                        withUnsafeMutablePointer(to: &month) {
                            m in
                            withUnsafeMutablePointer(to: &day) {
                                d in
                                args.append(y)
                                args.append(m)
                                args.append(d)
                            }
                        }
                    }

                    if vsscanf(value, "%4d%2d%2d", getVaList(args)) == 3 {
                        let components = DateComponents(year: year, month: month, day: day)

                        // This is bad, because we don't know the timezone...
                        endDate = Calendar.current.date(from: components)!
                    }
                }

                if endDate == nil {
                    throw RFC5545Exception.invalidRecurrenceRule
                }
                
                foundUntilOrCount = true

            case "COUNT":
                guard foundUntilOrCount == false, let ival = Int(value) else { throw RFC5545Exception.invalidRecurrenceRule }
                count = ival

                foundUntilOrCount = true

            case "INTERVAL":
                guard interval == nil, let ival = Int(value) else { throw RFC5545Exception.invalidRecurrenceRule }
                interval = ival

            case "BYDAY":
                guard daysOfTheWeek == nil else { throw RFC5545Exception.invalidRecurrenceRule }

                daysOfTheWeek = []

                let weekday: [String : EKWeekday] = [
                    "SU" : .sunday,
                    "MO" : .monday,
                    "TU" : .tuesday,
                    "WE" : .wednesday,
                    "TH" : .thursday,
                    "FR" : .friday,
                    "SA" : .saturday
                ]

                for day in value.components(separatedBy: ",") {
                    let dayStr: String
                    var num = 0

                    if day.count > 2 {
                        let index = day.index(day.endIndex, offsetBy: -2)
                        dayStr = String(day[index...])
                        num = Int(day[..<index]) ?? 0
                    } else {
                        dayStr = day
                    }

                    if let day = weekday[dayStr] {
                        daysOfTheWeek!.append(EKRecurrenceDayOfWeek(day, weekNumber: num))
                    }
                }

            case "BYMONTHDAY":
                guard daysOfTheMonth == nil else { throw RFC5545Exception.invalidRecurrenceRule }
                daysOfTheMonth = try allValues(lessThan: 32, csv: value)

            case "BYYEARDAY":
                guard daysOfTheYear == nil else { throw RFC5545Exception.invalidRecurrenceRule }
                daysOfTheYear = try allValues(lessThan: 367, csv: value)

            case "BYWEEKNO":
                guard weeksOfTheYear == nil else { throw RFC5545Exception.invalidRecurrenceRule }
                weeksOfTheYear = try allValues(lessThan: 54, csv: value)

            case "BYMONTH":
                guard monthsOfTheYear == nil else { throw RFC5545Exception.invalidRecurrenceRule }
                monthsOfTheYear = try allValues(lessThan: 13, csv: value)

            case "BYSETPOS":
                guard positions == nil else { throw RFC5545Exception.invalidRecurrenceRule }
                positions = try allValues(lessThan: 367, csv: value)

            default:
                throw RFC5545Exception.unsupportedRecurrenceProperty(key)
            }
        }

        guard let freq = frequency else { throw RFC5545Exception.invalidRecurrenceRule }

        // The BYDAY rule part MUST NOT be specified with a numeric value when the FREQ rule part is
        // not set to MONTHLY or YEARLY.
        if let daysOfTheWeek = daysOfTheWeek , freq != .monthly && freq != .yearly {
            for day in daysOfTheWeek {
                if day.weekNumber != 0 {
                    throw RFC5545Exception.invalidRecurrenceRule
                }
            }
        }

        // The BYMONTHDAY rule part MUST NOT be specified when the FREQ rule part is set to WEEKLY.
        if daysOfTheMonth != nil && freq == .weekly {
            throw RFC5545Exception.invalidRecurrenceRule
        }

        // The BYYEARDAY rule part MUST NOT be specified when the FREQ rule part is set to DAILY, WEEKLY, or MONTHLY.
        if daysOfTheYear != nil && (freq == .daily || freq == .weekly || freq == .monthly) {
            throw RFC5545Exception.invalidRecurrenceRule
        }

        // BYWEEKNO MUST NOT be used when the FREQ rule part is set to anything other than YEARLY
        if weeksOfTheYear != nil && freq != .yearly {
            throw RFC5545Exception.invalidRecurrenceRule
        }

        let nonPositionAllNil = daysOfTheYear == nil && daysOfTheMonth == nil && daysOfTheWeek == nil && weeksOfTheYear == nil && monthsOfTheYear == nil

        // If BYSETPOS is used, one of the other BY* rules must be used as well
        if positions != nil && nonPositionAllNil {
            throw RFC5545Exception.invalidRecurrenceRule
        }

        let end: EKRecurrenceEnd?
        if let endDate = endDate {
            end = EKRecurrenceEnd(end: endDate)
        } else if let count = count {
            end = EKRecurrenceEnd(occurrenceCount: count)
        } else {
            end = nil
        }


        if nonPositionAllNil && positions == nil {
            self.init(recurrenceWith: freq, interval: interval ?? 1, end: end)
        } else {
            // TODO: This needs to handle multiple BY* rules as defined by the RFC spec.  Maybe the EKRecurrenceRule
            // constructor does it for us, but it needs to be tested.
            self.init(recurrenceWith: freq, interval: interval ?? 1, daysOfTheWeek: daysOfTheWeek, daysOfTheMonth: daysOfTheMonth as [NSNumber]?, monthsOfTheYear: monthsOfTheYear as [NSNumber]?, weeksOfTheYear: weeksOfTheYear as [NSNumber]?, daysOfTheYear: daysOfTheYear as [NSNumber]?, setPositions: positions as [NSNumber]?, end: end)
        }
    }
}









































