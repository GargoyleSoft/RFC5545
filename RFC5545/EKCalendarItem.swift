//
//  EKCalendarItem.swift
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

extension EKCalendarItem {
    func rfc5545Base() -> [String] {
        var lines: [String] = []

        let ctime = creationDate ?? Date()

        let dateFormat: Rfc5545DateFormat = timeZone == nil ? .floating : .utc

        lines.append("UID:\(escape(text: calendarItemExternalIdentifier))")
        lines.append("CREATED:\(ctime.rfc5545(format: dateFormat))")
        lines.append("DTSTAMP:\(ctime.rfc5545(format: dateFormat))")

        if let lastModifiedDate = lastModifiedDate {
            lines.append("LAST-MODIFIED:\(lastModifiedDate.rfc5545(format: dateFormat))")
        }

        let ws = CharacterSet.whitespacesAndNewlines

        if let location = location?.trimmingCharacters(in: ws), !location.isEmpty {
            lines.append("LOCATION:\(escape(text: location))")
        }

        let summary = title.trimmingCharacters(in: ws)
        if !summary.isEmpty {
            lines.append("SUMMARY:\(escape(text: summary))")
        }

        if let notes = notes?.trimmingCharacters(in: ws), !notes.isEmpty {
            lines.append("DESCRIPTION:\(escape(text: notes))")
        }

        if let url = url {
            let path = url.path.trimmingCharacters(in: ws)

            // Apple will actually give us a non-null URL which is empty!
            if !path.isEmpty {
                lines.append("URL:\(escape(text: path))")
            }
        }

        if let recurrenceRules = recurrenceRules {
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

        return lines
    }

    /**
     *  Folds lines longer than 75 characters
     *
     *  - Parameter line: The line to fold
     *
     *  - SeeAlso: [RFC5545 Content Lines](https://tools.ietf.org/html/rfc5545#section-3.1)
     *
     *  - Returns: The folded text
     */
    func fold(line: String) -> String {
        var lines: [String] = []
        var start = line.startIndex
        let endIndex = line.endIndex

        var end = line.index(start, offsetBy: 75, limitedBy: endIndex)!
        lines.append(String(line[start..<end]))
        start = end

        while start != endIndex {
            // Note we use 74, instead of 75, because we have to account for the extra space we're adding
            end = line.index(start, offsetBy: 74, limitedBy: endIndex)!

            lines.append(" " + String(line[start..<end]))
            
            start = end
        }
        
        return lines.joined(separator: "\r\n")
    }

    /**
     *  Escapes the TEXT type blocks to add the \ characters as needed
     *
     *  - Parameter text: The text to escape.
     *
     *  - SeeAlso: [RFC5545 TEXT](https://tools.ietf.org/html/rfc5545#section-3.3.11)
     *
     *  - Returns: The escaped text.
     */
    func escape(text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

}
