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

public enum RFC5545Exception : Error {
    case missing(String)
    case invalidRecurrenceRule
    case invalidDateFormat
    case unsupportedRecurrenceProperty(String)
}

/// An object representing an RFC5545 compatible date.  The full RFC5545 spec is *not* implemented here.
/// This only represents those properties which relate to an `EKEvent`.
class RFC5545 {
    var startDate: Date!
    var endDate: Date!
    var summary: String!
    var notes: String?
    var location: String?
    var recurrenceRules: [EKRecurrenceRule]?
    var url: URL?
    var exclusions: [Date]?
    var allDay = false

    init(string: String) throws {
        let regex = try! NSRegularExpression(pattern: "\r\n[ \t]+", options: [])
        let lines = regex
            .stringByReplacingMatches(in: string, options: [], range: NSMakeRange(0, string.count), withTemplate: "")
            .components(separatedBy: "\r\n")

        exclusions = []
        recurrenceRules = []

        var startHasTimeComponent = false
        var endHasTimeComponent = false

        for line in lines {
            if line.hasPrefix("DTSTART:") || line.hasPrefix(("DTSTART;")) {
                let dateInfo = try parseDateString(line)
                startDate = dateInfo.date
                startHasTimeComponent = dateInfo.hasTimeComponent
            } else if line.hasPrefix("DTEND:") || line.hasPrefix(("DTEND;")) {
                let dateInfo = try parseDateString(line)
                endDate = dateInfo.date
                endHasTimeComponent = dateInfo.hasTimeComponent
            } else if line.hasPrefix("URL:") || line.hasPrefix(("URL;")) {
                if let text = unescape(text: line, startingAt: 4) {
                    url = URL(string: text)
                }
            } else if line.hasPrefix("SUMMARY:") {
                // This is the Subject of the event
                summary = unescape(text: line, startingAt: 8)
            } else if line.hasPrefix("DESCRIPTION:") {
                // This is the Notes of the event.
                notes = unescape(text: line, startingAt: 12)
            } else if line.hasPrefix("LOCATION:") {
                location = unescape(text: line, startingAt: 9)
            } else if line.hasPrefix("RRULE:") {
                let rule = try EKRecurrenceRule(rrule: line)
                recurrenceRules!.append(rule)
            } else if line.hasPrefix("EXDATE:") || line.hasPrefix("EXDATE;") {
                let dateInfo = try parseDateString(line)
                exclusions!.append(dateInfo.date)
            }
        }

        guard startDate != nil else {
            throw RFC5545Exception.missing("DTSTART")
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
                endDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: startDate)
            }
        }
    }

    /**
     *  Unescapes the TEXT type blocks to remove the \ characters that were added in.
     *
     *  - Parameter text: The text to unescape.
     *  - Parameter startingAt: The position in the string to start unescaping.
     *
     *  - SeeAlso: [RFC5545 TEXT](https://tools.ietf.org/html/rfc5545#section-3.3.11)
     *
     *  - Returns: The unescaped text or `nil` if there is no text after the indicated start position.
     */
    fileprivate func unescape(text: String, startingAt: Int) -> String? {
        guard text.count > startingAt else { return nil }

        return String(text[text.index(text.startIndex, offsetBy: startingAt)...])
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\n", with: "\n")
    }

    /**
     *  Generates an `EKEvent` from this object.
     *
     *  - Parameter store: The `EKEventStore` to which the event belongs.
     *  - Parameter calendar: The `EKCalendar` in which to create the event.
     *
     *  - Warning: While the RFC5545 spec allows multiple recurrence rules, iOS currently only honors the last rule.
     *
     *  - Returns: The created event.
     */
    func EKEvent(_ store: EKEventStore, calendar: EKCalendar?) -> EventKit.EKEvent {
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
        
        event.isAllDay = allDay
        event.url = url
        
        recurrenceRules?.forEach {
            event.addRecurrenceRule($0)
        }
        
        return event
    }
}

