//
//  EKEvent.swift
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




public extension EKEvent {
    /**
     * Convert the EKEvent to an RFC5545 compliant format.
     *
     * - Warning: This is not guaranteed to 100% match the `EKEvent`.  For example, iOS doesn't provide
     *   a list of the exclusions to a recurrent event.  You will somehow need to track those yourself
     *   and add them as an EXDATE entry.
     */
    public func rfc5545() -> String {
        var lines: [String] = ["BEGIN:VEVENT"]

        let dateFormat: Rfc5545DateFormat = timeZone == nil ? .floating : .utc

        if isAllDay {
            lines.append("DTSTART;VALUE=DATE:\(startDate.rfc5545(format: .day))")
            lines.append("DTEND;VALUE=DATE:\(endDate.rfc5545(format: .day))")
        } else {
            lines.append("DTSTART:\(startDate.rfc5545(format: dateFormat))")
            lines.append("DTEND:\(endDate.rfc5545(format: dateFormat))")
        }

        let ws = CharacterSet.whitespacesAndNewlines

        // Remember super already wrote out the LOCATION line so don't repeat it here
        if let location = location?.trimmingCharacters(in: ws) , !location.isEmpty,
            let structuredLocation = structuredLocation, let geo = structuredLocation.geoLocation {
            lines.append("X-APPLE-TRAVEL-ADVISORY-BEHAVIOR:AUTOMATIC")
            lines.append("X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS=\(escape(text: location));X-APPLE-RADIUS=\(structuredLocation.radius);X-TITLE=\(escape(text: structuredLocation.title!)):geo:\(geo.coordinate.latitude),\(geo.coordinate.longitude)")
        }

        if hasRecurrenceRules && isDetached {
            lines.append("RECURRENCE-ID:\(occurrenceDate.rfc5545(format: .utc))")
        }

        lines += super.rfc5545Base()

        lines.append("END:VEVENT")

        return lines.map {
            fold(line: $0)
        }.joined(separator: "\r\n")
    }

    /**
     *  Converts the RFC5545 text block to an `EKEvent` object.
     *
     *  - Important: Not all RFC5545 elements are convertible.  For example:
     *       - iOS can't set the Organizer
     *       - iOS can't set the UID
     *       - RRULE doesn't support the WKST property
     *
     *  - Parameter rfc5545: The block of text to parse.
     *  - Parameter store: The `EKEventStore` to use when creating the event.
     *  - Parameter calendar: The `EKCalendar` to use for the event.
     *
     *  - Returns: A tuple containing the created event, as well as a list of dates which should be excluded if the
     *    event is recurring.
     *
     *  - Throws: An `RFC5545Exception`
     */
    public func parse(rfc5545: String, store: EKEventStore, calendar: EKCalendar? = nil) throws -> (event: EKEvent, exclusions: [Date]?) {
        let rfc = try RFC5545(string: rfc5545)
        
        return (event: rfc.EKEvent(store, calendar: calendar), exclusions: rfc.exclusions)
    }
}
