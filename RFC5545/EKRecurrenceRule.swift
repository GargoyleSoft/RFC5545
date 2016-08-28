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
                text += ";UNTIL=\(date.rfc5545(format: .utc))"
            } else {
                text += ";COUNT=\(end.occurrenceCount)"
            }
        }

        return text
    }
}