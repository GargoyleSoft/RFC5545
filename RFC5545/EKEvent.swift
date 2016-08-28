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

/// Escapes the TEXT type blocks to add the \ characters that as needed
///
/// - Parameter text: The text to escape.
///
/// - SeeAlso: [RFC5545 TEXT](https://tools.ietf.org/html/rfc5545#section-3.3.11)
///
/// - Returns: The escaped text.
private func escapeText(text: String) -> String {
    return text
        .stringByReplacingOccurrencesOfString("\\", withString: "\\\\")
        .stringByReplacingOccurrencesOfString(";", withString: "\\;")
        .stringByReplacingOccurrencesOfString(",", withString: "\\,")
        .stringByReplacingOccurrencesOfString("\n", withString: "\\n")
}

/// Folds lines longer than 75 characters
///
/// - Parameter line: The line to fold
///
/// - SeeAlso: [RFC5545 Content Lines](https://tools.ietf.org/html/rfc5545#section-3.1)
///
/// - Returns: The folded text
private func foldLine(line: String) -> String {
    var lines: [String] = []
    var start = line.startIndex
    let endIndex = line.endIndex

    let end = start.advancedBy(75, limit: endIndex)
    lines.append(line.substringWithRange(start..<end))
    start = end

    while start != endIndex {
        // Note we use 74, instead of 75, because we have to account for the extra space we're adding
        let end = start.advancedBy(74, limit: endIndex)

        lines.append(" " + line.substringWithRange(start..<end))

        start = end
    }

    return lines.joinWithSeparator("\r\n")
}

public extension EKEvent {
    /**
     * Convert the EKEvent to an RFC5545 compliant format.
     *
     * - Parameter uid: The UID string to use.  You **should** provide this value to be compliant with the
     *   RFC5545 specification.  If you do not, a simple `UUID` will be used.
     *
     * - Warning: This is not guaranteed to 100% match the `EKEvent`.  For example, iOS doesn't provide
     *   a list of the exclusions to a recurrent event.  You will somehow need to track those yourself
     *   and add them as an EXDATE entry.
     *
     * - SeeAlso: [RFC5545 UID](https://tools.ietf.org/html/rfc5545#section-3.8.4.7)
     */
    public func rfc5545(uid uid: String? = nil) -> String {
        var lines: [String] = ["BEGIN:VEVENT"]

        // https://tools.ietf.org/html/rfc5545#section-3.8.4.7
        if let uid = uid {
            lines.append("UID:\(uid)")
        } else {
            lines.append("UID:\(NSUUID().UUIDString)")
        }

        let ctime = creationDate ?? NSDate()

        let dateFormat: Rfc5545DateFormat = timeZone == nil ? .floating : .utc

        // https://tools.ietf.org/html/rfc5545#section-3.8.7.1
        lines.append("CREATED:\(ctime.rfc5545(format: dateFormat))")

        // https://tools.ietf.org/html/rfc5545#section-3.8.7.2
        lines.append("DTSTAMP:\(ctime.rfc5545(format: dateFormat))")

        // https://tools.ietf.org/html/rfc5545#section-3.8.7.3
        if let lastModifiedDate = lastModifiedDate {
            lines.append("LAST-MODIFIED:\(lastModifiedDate.rfc5545(format: dateFormat))")
        } else {
            lines.append("LAST-MODIFIED:\(ctime.rfc5545(format: dateFormat))")
        }

        // https://tools.ietf.org/html/rfc5545#section-3.8.2.4
        // https://tools.ietf.org/html/rfc5545#section-3.8.2.2
        if allDay {
            lines.append("DTSTART;VALUE=DATE:\(startDate.rfc5545(format: .day))")
            lines.append("DTEND;VALUE=DATE:\(endDate.rfc5545(format: .day))")
        } else {
            lines.append("DTSTART:\(startDate.rfc5545(format: dateFormat))")
            lines.append("DTEND:\(endDate.rfc5545(format: dateFormat))")
        }

        let ws = NSCharacterSet.whitespaceAndNewlineCharacterSet()

        let summary = title.stringByTrimmingCharactersInSet(ws)
        if !summary.isEmpty {
            // https://tools.ietf.org/html/rfc5545#section-3.8.1.12
            lines.append("SUMMARY:\(escapeText(summary))")
        }

        // https://tools.ietf.org/html/rfc5545#section-3.8.1.5
        if let notes = notes?.stringByTrimmingCharactersInSet(ws) where !notes.isEmpty {
            lines.append("DESCRIPTION:\(escapeText(notes))")
        }

        // https://tools.ietf.org/html/rfc5545#section-3.8.1.7
        if let location = location?.stringByTrimmingCharactersInSet(ws) where !location.isEmpty {
            lines.append("LOCATION:\(escapeText(location))")

            if let structuredLocation = structuredLocation, let geo = structuredLocation.geoLocation {
                lines.append("X-APPLE-TRAVEL-ADVISORY-BEHAVIOR:AUTOMATIC")
                lines.append("X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS=\(escapeText(location));X-APPLE-RADIUS=\(structuredLocation.radius);X-TITLE=\(escapeText(structuredLocation.title)):geo:\(geo.coordinate.latitude),\(geo.coordinate.longitude)")
            }
        }

        // https://tools.ietf.org/html/rfc5545#section-3.8.4.6
        if let url = URL, let path = url.path {
            // Apple will actually give us a non-null URL which is empty!
            let trimmed = path.stringByTrimmingCharactersInSet(ws)
            if !trimmed.isEmpty {
                lines.append("URL:\(escapeText(trimmed))")
            }
        }

        if let recurrenceRules = recurrenceRules {
            if isDetached {
                lines.append("RECURRENCE-ID:\(occurrenceDate.rfc5545(format: .utc))")
            }

            recurrenceRules.forEach {
                lines.append($0.rfc5545())
            }
        }

        alarms?.forEach {
            lines += $0.rfc5545()
        }

        attendees?.forEach {
            lines.append($0.rfc5545())
        }

        lines.append("END:VEVENT")

        return lines.map {
            foldLine($0)
        }.joinWithSeparator("\r\n")
    }

    /// Converts the RFC5545 text block to an `EKEvent` object.
    ///
    /// - Warning: Not all RFC5545 elements are convertible.  For example, iOS can't set the Organizer, nor does it handle the WKST property to set
    ///   the start of the week.
    /// - Parameter text: The block of text to parse.
    /// - Parameter store: The `EKEventStore` to use when creating the event.
    /// - Parameter calendar: The `EKCalendar` to use for the event.
    /// - Returns: A tuple containing the created event, as well as a list of dates which should be excluded if the event is recurring.
    /// - Throws: An `RFC5545Exception`
    public func parseRfc5545(text: String, store: EKEventStore, calendar: EKCalendar? = nil) throws -> (event: EKEvent, exclusions: [NSDate]?) {
        let rfc = try RFC5545(string: text)
        
        return (event: rfc.EKEvent(store, calendar: calendar), exclusions: rfc.exclusions)
    }
}