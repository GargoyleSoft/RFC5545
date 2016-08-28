//
//  NSDate.swift
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

enum Rfc5545DateFormat {
    case floating
    case day
    case utc
}

extension NSDate {
    /// Converts an `NSDate` to an RFC5545 formatted DATE-TIME or DATE
    ///
    /// - Parameter format: The format of date to ouput.
    ///
    /// - Returns: The formatted RFC5545 string
    ///
    /// - SeeAlso: [RFC5545 DATE](https://tools.ietf.org/html/rfc5545#section-3.3.4)
    /// - SeeAlso: [RFC5545 DATE-TIME](https://tools.ietf.org/html/rfc5545#section-3.3.5)
    func rfc5545(format format: Rfc5545DateFormat) -> String {
        var time = time_t(timeIntervalSince1970)

        let fmt: String
        let count: Int

        switch format {
        case .day:
            fmt = "%Y%m%d"
            count = 9

        case .floating:
            fmt = "%Y%m%dT%H%M%S"
            count = 16

        case .utc:
            fmt = "%Y%m%dT%H%M%SZ"
            count = 17
        }

        var buffer = [Int8](count: count, repeatedValue: 0)
        strftime_l(&buffer, buffer.count, fmt, localtime(&time), nil)

        return String.fromCString(buffer)!
    }
}