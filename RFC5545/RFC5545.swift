//
//  RFC5545.swift
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

public enum RFC5545Exception : ErrorType {
    case MissingStartDate
    case MissingEndDate
    case MissingSummary
    case InvalidRecurrenceRule
    case InvalidDateFormat
    case UnsupportedRecurrenceProperty
}

/// An object representing an RFC5545 compatible date.  The full RFC5545 spec is *not* implemented here.
/// This only represents those properties which relate to an `EKEvent`.
public class RFC5545 {
    var startDate: NSDate!
    var endDate: NSDate!
    var summary: String!
    var notes: String?
    var location: String?
    var recurrenceRules: [EKRecurrenceRule]?
    var url: NSURL?
    var exclusions: [NSDate]?
    var allDay = false

    init(string: String) throws {
        let lines = string
            .stringByReplacingOccurrencesOfString("\r\n ", withString: "")
            .componentsSeparatedByString("\r\n")

        exclusions = []
        recurrenceRules = []

        var startHasTimeComponent = false
        var endHasTimeComponent = false

        for line in lines {
            if line.hasPrefix("DTSTART:") || line.hasPrefix(("DTSTART;")) {
                let dateInfo = try RFC5545.parseDateString(line)
                startDate = dateInfo.date
                startHasTimeComponent = dateInfo.hasTimeComponent
            } else if line.hasPrefix("DTEND:") || line.hasPrefix(("DTEND;")) {
                let dateInfo = try RFC5545.parseDateString(line)
                endDate = dateInfo.date
                endHasTimeComponent = dateInfo.hasTimeComponent
            } else if line.hasPrefix("URL:") || line.hasPrefix(("URL;")) {
                if let text = RFC5545.unescapeText(line, startingAt: 4) {
                    url = NSURL(string: text)
                }
            } else if line.hasPrefix("SUMMARY:") {
                // This is the Subject of the event
                summary = RFC5545.unescapeText(line, startingAt: 8)
            } else if line.hasPrefix("DESCRIPTION:") {
                // This is the Notes of the event.
                notes = RFC5545.unescapeText(line, startingAt: 12)
            } else if line.hasPrefix("LOCATION:") {
                location = RFC5545.unescapeText(line, startingAt: 9)
            } else if line.hasPrefix("RRULE:") {
                let rule = try RFC5545.parseRecurrenceRule(line)
                recurrenceRules!.append(rule)
            } else if line.hasPrefix("EXDATE:") || line.hasPrefix("EXDATE;") {
                let dateInfo = try RFC5545.parseDateString(line)
                exclusions!.append(dateInfo.date)
            }
        }

        guard startDate != nil else {
            throw RFC5545Exception.MissingStartDate
        }

        if exclusions!.isEmpty {
            exclusions = nil
        }

        if recurrenceRules!.isEmpty {
            recurrenceRules = nil
        }

        if !(startHasTimeComponent || endHasTimeComponent) {
            allDay = true
        } else if endDate == nil {
            if startHasTimeComponent {
                // For cases where a "VEVENT" calendar component specifies a "DTSTART" property with a DATE-TIME
                // data type but no "DTEND" property, the event ends on the same calendar date and time of day
                // specified by the "DTSTART" property.
                endDate = startDate
            } else {
                // For cases where a "VEVENT" calendar component specifies a "DTSTART" property with a DATE
                // data type but no "DTEND" property, the events non-inclusive end is the end of the calendar
                // date specified by the "DTSTART" property.
                let calendar = NSCalendar.currentCalendar()
                let components = calendar.components([.Era, .Year, .Month, .Day], fromDate: startDate)
                components.hour = 23
                components.minute = 59
                components.second = 59

                endDate = calendar.dateFromComponents(components)
            }
        }
    }

    /// Unescapes the TEXT type blocks to remove the \ characters that were added in.
    ///
    /// - Parameter text: The text to unescape.
    /// - Parameter startingAt: The position in the string to start unescaping.
    /// - SeeAlso: [RFC5545 TEXT](http://google-rfc-2445.googlecode.com/svn/trunk/RFC5545.html#4.3.11)
    /// - Returns: The unescaped text or `nil` if there is no text after the indicated start position.
    private static func unescapeText(text: String, startingAt: Int) -> String? {
        guard text.characters.count > startingAt else { return nil }

        return text
            .substringFromIndex(text.startIndex.advancedBy(startingAt))
            .stringByReplacingOccurrencesOfString("\\;", withString: ";")
            .stringByReplacingOccurrencesOfString("\\,", withString: ",")
            .stringByReplacingOccurrencesOfString("\\\\", withString: "\\")
    }

    /// Splits the input string by comma and returns an array of all values which are less than the
    /// constraint value.
    ///
    /// - Parameter constrain: The value that the numbers must be less than.
    /// - Parameter csv: The comma separated input data.
    /// - Returns: An array of `int` which are less than `constrain`.
    private static func allValues(lessThan lessThan: Int, csv: String) -> [Int] {
        var ret: [Int] = []

        for dayNum in csv.componentsSeparatedByString(",") {
            if let num = Int(dayNum) where abs(num) < lessThan {
                ret.append(num)
            }
        }

        return ret
    }

    /// Parses a date string and determines whether or not it includes a time component.
    ///
    /// - Parameter str: The date string to parse.
    /// - Returns: A tuple containing the `NSDate` as well as a `Bool` specifying whether or not there is a time component.
    /// - Throws: `RFC5545Exception.InvalidDateFormat`: The date is not in a correct format.
    /// - SeeAlso: [RFC5545 Date](http://google-rfc-2445.googlecode.com/svn/trunk/RFC5545.html#4.3.4)
    /// - SeeAlso: [RFC5545 Date-Time](http://google-rfc-2445.googlecode.com/svn/trunk/RFC5545.html#4.3.5)
    /// - Note: If a time is not specified in the input, the time of the returned `NSDate` is set to noon.
    static func parseDateString(str: String) throws -> (date: NSDate, hasTimeComponent: Bool) {
        var dateStr: String!
        var options: [String : String] = [:]

        let delim = NSCharacterSet(charactersInString: ";:")
        for param in str.componentsSeparatedByCharactersInSet(delim) {
            let keyValuePair = param.componentsSeparatedByString("=")
            if keyValuePair.count == 1 {
                dateStr = keyValuePair[0]
            } else {
                options[keyValuePair[0]] = keyValuePair[1]
            }
        }

        if dateStr == nil && options.isEmpty {
            dateStr = str
        }

        let components = NSDateComponents()

        let needsTime: Bool
        if let value = options["VALUE"] {
            needsTime = value != "DATE"
        } else {
            needsTime = true
        }

        var year = 0
        var month = 0
        var day = 0
        var hour = 0
        var minute = 0
        var second = 0

        var args: [CVarArgType] = []

        withUnsafeMutablePointers(&year, &month, &day) {
            y, m, d in
            args.append(y)
            args.append(m)
            args.append(d)
        }

        if needsTime {
            withUnsafeMutablePointers(&hour, &minute, &second) {
                h, m, s in
                args.append(h)
                args.append(m)
                args.append(s)
            }

            if let tzid = options["TZID"], tz = NSTimeZone(name: tzid) {
                components.timeZone = tz
            } else {
                throw RFC5545Exception.InvalidDateFormat
            }

            if dateStr.characters.last! == "Z" {
                guard components.timeZone == nil else { throw RFC5545Exception.InvalidDateFormat }
                components.timeZone = NSTimeZone(forSecondsFromGMT: 0)
            }

            if vsscanf(dateStr, "%4d%2d%2dT%2d%2d%2d", getVaList(args)) == 6 {
                components.year = year
                components.month = month
                components.day = day
                components.hour = hour
                components.minute = minute
                components.second = second

                if let date = NSCalendar.currentCalendar().dateFromComponents(components) {
                    return (date: date, hasTimeComponent: true)
                }
            }
        } else if vsscanf(dateStr, "%4d%2d%2d", getVaList(args)) == 3 {
            components.year = year
            components.month = month
            components.day = day

            let calendar = NSCalendar.currentCalendar()
            if let date = calendar.dateFromComponents(components) {
                return (date: date, hasTimeComponent: false)
            }
        }

        throw RFC5545Exception.InvalidDateFormat
    }

    /// Parses an RRULE pattern.
    ///
    /// - Parameter str: The string to parse.
    /// - Throws: `RFC5545Exception.InvalidRecurrenceRule`
    /// - Throws: `RFC5545Exception.UnsupportedRecurrenceProperty`
    /// - Returns: The generated rule.
    /// - SeeAlso: [RFC5545 RRULE](http://google-rfc-2445.googlecode.com/svn/trunk/RFC5545.html#4.8.5.4)
    /// - SeeAlso: [RFC5545 Recurrence Rule](http://google-rfc-2445.googlecode.com/svn/trunk/RFC5545.html#4.3.10)
    private static func parseRecurrenceRule(str: String) throws -> EKRecurrenceRule {
        // Make sure it's not just the RRULE: part
        guard str.characters.count > 6 else { throw RFC5545Exception.InvalidRecurrenceRule }

        var frequency: EKRecurrenceFrequency!
        var interval = 1
        var endDate: NSDate!
        var foundUntilOrCount = false
        var count: Int?

        var daysOfTheWeek: [EKRecurrenceDayOfWeek]?
        var daysOfTheMonth: [NSNumber]?
        var weeksOfTheYear: [NSNumber]?
        var monthsOfTheYear: [NSNumber]?
        var daysOfTheYear: [NSNumber]?
        var positions: [NSNumber]?

        let index = str.startIndex.advancedBy(6)
        for part in str.substringFromIndex(index).componentsSeparatedByString(";") {
            let keyValue = part.componentsSeparatedByString("=")
            guard keyValue.count == 2 else { throw RFC5545Exception.InvalidRecurrenceRule }

            let key = keyValue[0]

            if key.lowercaseString.hasPrefix("x-") {
                continue
            }

            let value = keyValue[1]

            switch key {
            case "FREQ":
                switch value {
                case "DAILY": frequency = .Daily
                case "MONTHLY": frequency = .Monthly
                case "WEEKLY": frequency = .Weekly
                case "YEARLY": frequency = .Yearly
                case "SECONDLY", "MINUTELY": break
                default: throw RFC5545Exception.InvalidRecurrenceRule
                }

            case "INTERVAL":
                guard let ival = Int(value) else { throw RFC5545Exception.InvalidRecurrenceRule }
                interval = ival

            case "UNTIL":
                guard foundUntilOrCount == false else { throw RFC5545Exception.InvalidRecurrenceRule }

                do {
                    let dateInfo = try RFC5545.parseDateString(value)
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

            case "BYDAY":
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
                daysOfTheMonth = RFC5545.allValues(lessThan: 32, csv: value)

            case "BYYEARDAY":
                daysOfTheYear = RFC5545.allValues(lessThan: 367, csv: value)

            case "BYWEEKNO":
                weeksOfTheYear = RFC5545.allValues(lessThan: 54, csv: value)

            case "BYMONTH":
                monthsOfTheYear = RFC5545.allValues(lessThan: 13, csv: value)

            case "BYSETPOS":
                positions = RFC5545.allValues(lessThan: 367, csv: value)

            case "BYSECOND", "BYMINUTE", "BYHOUR", "BYWEEKNO", "WKST":
                throw RFC5545Exception.UnsupportedRecurrenceProperty

            default:
                throw RFC5545Exception.InvalidRecurrenceRule
            }
        }

        guard frequency != nil else { throw RFC5545Exception.InvalidRecurrenceRule }

        let end: EKRecurrenceEnd?
        if let endDate = endDate {
            end = EKRecurrenceEnd(endDate: endDate)
        } else if let count = count {
            end = EKRecurrenceEnd(occurrenceCount: count)
        } else {
            end = nil
        }

        if daysOfTheMonth != nil || daysOfTheWeek != nil || daysOfTheYear != nil || monthsOfTheYear != nil || weeksOfTheYear != nil || positions != nil {
            return EKRecurrenceRule(recurrenceWithFrequency: frequency, interval: interval, daysOfTheWeek: daysOfTheWeek, daysOfTheMonth: daysOfTheMonth, monthsOfTheYear: monthsOfTheYear, weeksOfTheYear: weeksOfTheYear, daysOfTheYear: daysOfTheYear, setPositions: positions, end: end)
        } else {
            return EKRecurrenceRule(recurrenceWithFrequency: frequency, interval: interval, end: end)
        }
    }

    /// Generates an `EKEvent` from this object.
    ///
    /// - Parameter store: The `EKEventStore` to which the event belongs.
    /// - Parameter calendar: The `EKCalendar` in which to create the event.
    /// - Warning: While the RFC5545 spec allows multiple recurrence rules, iOS currently only honors the last rule.
    /// - Returns: The created event.
    func EKEvent(store: EKEventStore, calendar: EKCalendar?) -> EventKit.EKEvent {
        let event = EventKit.EKEvent(eventStore: store)
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.location = location
        
        if let calendar = calendar {
            event.calendar = calendar
        }
        
        if let title = summary {
            event.title = title
        }
        
        event.allDay = allDay
        event.URL = url
        
        recurrenceRules?.forEach {
            event.addRecurrenceRule($0)
        }
        
        return event
    }
}

