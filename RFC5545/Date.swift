//
//  Date.swift
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

extension Date {
    /**
     *  Converts an `Date` to an RFC5545 formatted DATE-TIME or DATE
     *
     *  - Parameter format: The format of date to ouput.
     *
     *  - Returns: The formatted RFC5545 string
     *
     *  - SeeAlso: [RFC5545 DATE](https://tools.ietf.org/html/rfc5545#section-3.3.4)
     *  - SeeAlso: [RFC5545 DATE-TIME](https://tools.ietf.org/html/rfc5545#section-3.3.5)
     */
    func rfc5545(format: Rfc5545DateFormat) -> String {
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

        var buffer = [Int8](repeating: 0, count: count)
        strftime_l(&buffer, buffer.count, fmt, localtime(&time), nil)

        return String(cString: buffer)
    }
}

/**
 * Parses a date string and determines whether or not it includes a time component.
 *
 *  - Parameter str: The date string to parse.
 *
 *  - Returns: A tuple containing the `Date` as well as a `Bool` specifying whether or not there is a time component.
 *
 *  - Throws: `RFC5545Exception.InvalidDateFormat`: The date is not in a correct format.
 *
 *  - SeeAlso: [RFC5545 Date](https://tools.ietf.org/html/rfc5545#section-3.3.4)
 *  - SeeAlso: [RFC5545 Date-Time](https://tools.ietf.org/html/rfc5545#section-3.3.5)
 *
 *  - Note: If a time is not specified in the input, the time of the returned `Date` is set to noon.
 */
func parseDateString(_ str: String) throws -> (date: Date, hasTimeComponent: Bool) {
    var dateStr: String!
    var options: [String : String] = [:]

    let delim = CharacterSet(charactersIn: ";:")
    for param in str.components(separatedBy: delim) {
        let keyValuePair = param.components(separatedBy: "=")
        if keyValuePair.count == 1 {
            dateStr = keyValuePair[0]
        } else {
            options[keyValuePair[0]] = keyValuePair[1]
        }
    }

    if dateStr == nil && options.isEmpty {
        dateStr = str
    }

    let needsTime: Bool
    if let value = options["VALUE"] {
        needsTime = value != "DATE"
    } else {
        needsTime = true
    }

    var year = 0
    var month = 0
    var day = 0

    var args: [CVarArg] = []

    withUnsafeMutablePointer(to: &year) {
        y in
        withUnsafeMutablePointer(to: &month) {
            m in
            withUnsafeMutablePointer(to: &day) {
                d in
                args.append(y)
                args.append(m)
                args.append(d)
            }
        }
    }

    var components = DateComponents()

    if needsTime {
        var hour = 0
        var minute = 0
        var second = 0

        withUnsafeMutablePointer(to: &hour) {
            h in
            withUnsafeMutablePointer(to: &minute) {
                m in
                withUnsafeMutablePointer(to: &second) {
                    s in

                    args.append(h)
                    args.append(m)
                    args.append(s)
                }
            }
        }

        if let tzid = options["TZID"], let tz = TimeZone(identifier: tzid) {
            components.timeZone = tz
        } else {
            throw RFC5545Exception.invalidDateFormat
        }

        if dateStr.last! == "Z" {
            guard components.timeZone == nil else { throw RFC5545Exception.invalidDateFormat }
            components.timeZone = TimeZone(secondsFromGMT: 0)
        }

        if vsscanf(dateStr, "%4d%2d%2dT%2d%2d%2d", getVaList(args)) == 6 {
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            components.second = second

            if let date = Calendar.current.date(from: components) {
                return (date: date, hasTimeComponent: true)
            }
        }
    } else if vsscanf(dateStr, "%4d%2d%2d", getVaList(args)) == 3 {
        components.year = year
        components.month = month
        components.day = day

        if let date = Calendar.current.date(from: components) {
            return (date: date, hasTimeComponent: false)
        }
    }
    
    throw RFC5545Exception.invalidDateFormat
}

