//
//  EKParticipant.swift
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

extension EKParticipant {
    /**
     * Converts an `EKParticipant` into an RFC5545 compatible format.
     *
     * - Returns: A `String` representing the attendee. 
     *
     * - SeeAlso: [RFC5545 Attendee](https://tools.ietf.org/html/rfc5545#section-3.8.4.1)
     */
    func rfc5545() -> String {
        var lines: [String] = ["ATTENDEE"]

        if let name = name {
            lines.append("CN=\(name)")
        }

        let type: String
        switch participantType {
        case .Group: type = "GROUP"
        case .Person: type = "INDIVIDUAL"
        case .Resource: type = "RESOURCE"
        case .Room: type = "ROOM"
        case .Unknown: type = "UNKNOWN"
        }

        lines.append("CUTYPE=\(type)")

        let role: String?
        switch participantRole {
        case .Chair: role = "CHAIR"
        case .NonParticipant: role = "NON-PARTICIPANT"
        case .Optional: role = "OPT-PARTICIPANT"
        case .Required: role = "REQ-PARTICIPANT"
        default: role = nil
        }

        if let role = role {
            lines.append("ROLE=\(role)")
        }

        let status: String?
        switch participantStatus {
        case .Accepted: status = "ACCEPTED"
        case .Declined: status = "DECLINED"
        case .Delegated: status = "DELEGATED"
        case .Tentative: status = "TENTATIVE"
        default: status = nil
        }
        
        if let status = status {
            lines.append("PARTSTAT=\(status)")
        }

        return lines.joinWithSeparator(";")
    }
}