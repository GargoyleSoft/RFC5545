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
    func rfc5545() -> [String] {
        var lines: [String] = []

        let ctime = creationDate ?? NSDate()

        let dateFormat: Rfc5545DateFormat = timeZone == nil ? .floating : .utc

        lines.append("CREATED:\(ctime.rfc5545(format: dateFormat))")
        lines.append("DTSTAMP:\(ctime.rfc5545(format: dateFormat))")

        if let lastModifiedDate = lastModifiedDate {
            lines.append("LAST-MODIFIED:\(lastModifiedDate.rfc5545(format: dateFormat))")
        }

        let ws = NSCharacterSet.whitespaceAndNewlineCharacterSet()

        if let location = location?.stringByTrimmingCharactersInSet(ws) where !location.isEmpty {
            lines.append("LOCATION:\(escapeText(location))")
        }

        let summary = title.stringByTrimmingCharactersInSet(ws)
        if !summary.isEmpty {
            lines.append("SUMMARY:\(escapeText(summary))")
        }

        if let notes = notes?.stringByTrimmingCharactersInSet(ws) where !notes.isEmpty {
            lines.append("DESCRIPTION:\(escapeText(notes))")
        }

        if let url = URL, let path = url.path {
            // Apple will actually give us a non-null URL which is empty!
            let trimmed = path.stringByTrimmingCharactersInSet(ws)
            if !trimmed.isEmpty {
                lines.append("URL:\(escapeText(trimmed))")
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
}