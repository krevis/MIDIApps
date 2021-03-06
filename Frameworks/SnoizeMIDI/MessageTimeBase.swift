/*
 Copyright (c) 2008-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
        let hostTimeInNanos = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime())
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
            self.hostTimeInNanos = UInt64(coder.decodeInt64(forKey: "hostTimeInNanos"))
        }
        else {
            // fallback: inaccurate because the HostTime to nanos
            // ratio may have changed from when this was archived
            self.hostTimeInNanos = AudioConvertHostTimeToNanos(UInt64(coder.decodeInt64(forKey: "hostTime")))
        }
        self.timeInterval = coder.decodeDouble(forKey: "timeInterval")
        super.init()
    }

    public func encode(with coder: NSCoder) {
        coder.encode(Int64(hostTimeInNanos), forKey: "hostTimeInNanos")

        coder.encode(Int64(AudioConvertNanosToHostTime(hostTimeInNanos)), forKey: "hostTime") // backwards compatibility

        coder.encode(Double(timeInterval), forKey: "timeInterval")
    }

    let hostTimeInNanos: UInt64
    let timeInterval: TimeInterval

}
