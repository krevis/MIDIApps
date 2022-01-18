/*
 Copyright (c) 2008-2022, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreAudio

// NOTE: This is the wrong way to do things. Host time may pause while the system is asleep, but clock time will not.
// So this single snapshot of a relationship between host time and clock time is only useful until the system sleeps.
// See also https://developer.apple.com/library/archive/technotes/tn2169/_index.html
//
// This class is only present for backwards compatibility.

class MessageTimeBase: NSObject, NSCoding {

    static var current: MessageTimeBase = {
        // Establish a base of what host time corresponds to what clock time.
        let hostTimeInNanos = SMConvertHostTimeToNanos(SMGetCurrentHostTime())
        let timeInterval = Date.timeIntervalSinceReferenceDate
        return MessageTimeBase(hostTimeInNanos: hostTimeInNanos, timeInterval: timeInterval)
    }()

    init(hostTimeInNanos: UInt64, timeInterval: TimeInterval) {
        self.hostTimeInNanos = hostTimeInNanos
        self.timeInterval = timeInterval
        super.init()
    }

    required init?(coder: NSCoder) {
        if coder.containsValue(forKey: "hostTimeInNanos") {
            self.hostTimeInNanos = UInt64(bitPattern: coder.decodeInt64(forKey: "hostTimeInNanos"))
        }
        else {
            // fallback: inaccurate because the HostTime to nanos
            // ratio may have changed from when this was archived
            self.hostTimeInNanos = SMConvertHostTimeToNanos(UInt64(bitPattern: coder.decodeInt64(forKey: "hostTime")))
        }
        self.timeInterval = coder.decodeDouble(forKey: "timeInterval")
        super.init()
    }

    public func encode(with coder: NSCoder) {
        coder.encode(Int64(bitPattern: hostTimeInNanos), forKey: "hostTimeInNanos")

        coder.encode(Int64(bitPattern: SMConvertNanosToHostTime(hostTimeInNanos)), forKey: "hostTime") // backwards compatibility

        coder.encode(Double(timeInterval), forKey: "timeInterval")
    }

    let hostTimeInNanos: UInt64
    let timeInterval: TimeInterval

}
