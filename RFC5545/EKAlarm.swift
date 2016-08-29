//
//  EKAlarm.swift
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

extension EKAlarm {
    /**
     *  Converts the `EKAlarm` into an RFC5545 compatible format.
     *
     *  - Returns: An `[String]` representing the lines of the alarm description.
     *
     *  - SeeAlso: [RFC5545 Alarm Component](https://tools.ietf.org/html/rfc5545#section-3.6.6)
     */
    func rfc5545() -> [String] {
        var lines = ["BEGIN:VALARM"]

        // https://tools.ietf.org/html/rfc5545#section-3.8.6.3
        if let date = absoluteDate {
            lines.append("TRIGGER;VALUE=DATE-TIME:\(date.rfc5545(format: .day)))")
        } else {
            var offset = Int(relativeOffset)

            var str = ""
            if offset < 0 {
                str = "-"
                offset *= -1
            }

            let week = 604_800

            if offset % week == 0 {
                str += "\(offset / week)W"
            } else {
                let seconds = offset % 60
                let minutes = (offset / 60) % 60
                let hours = (offset / 3_600) % 24
                let days = offset / 86_400

                if days > 0 {
                    str += "\(days)D"
                }

                if hours > 0 || minutes > 0 || seconds > 0 {
                    str += "T"

                    if hours > 0 {
                        str += "\(hours)H"
                    }

                    if minutes > 0 {
                        str += "\(minutes)M"
                    }

                    if seconds > 0 {
                        if hours > 0 && minutes == 0 {
                            str += "0M"
                        }

                        str += "\(seconds)S"
                    }
                }
            }

            lines.append("TRIGGER:\(str)")
        }

        lines.append("DESCRIPTION:Reminder")
        lines.append("ACTION:DISPLAY")
        lines.append("END:VALARM")
        
        return lines
    }
}
