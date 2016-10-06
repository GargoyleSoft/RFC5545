//
//  EKReminder.swift
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

public extension EKReminder {
    /**
     * Converts the `EKReminder` into an RFC5545 compatible format.
     *
     * - SeeAlso: [RFC5545 To-Do Component](https://tools.ietf.org/html/rfc5545#section-3.6.2)
     */
    public func rfc5545(calendar cal: Calendar? = nil) -> String {
        var lines = ["BEGIN:VTODO"]

        let calendar = cal ?? Calendar.current

        if let startDateComponents = startDateComponents
            , !(startDateComponents.hour == 0 && startDateComponents.minute == 0 && startDateComponents.second == 0),
            let start = calendar.date(from: startDateComponents) {
            lines.append("DTSTART:\(start.rfc5545(format: .utc))")
        }

        if let dueDateComponents = dueDateComponents, let due = calendar.date(from: dueDateComponents) {
            lines.append("DUE:\(due.rfc5545(format: .utc))")
        }

        if let completionDate = completionDate {
            lines.append("COMPLETED:\(completionDate.rfc5545(format: .utc))")
        }

        lines += super.rfc5545Base()

        lines.append("END:VTODO")

        return lines.map {
            fold(line: $0)
        }.joined(separator: "\r\n")
    }
}
