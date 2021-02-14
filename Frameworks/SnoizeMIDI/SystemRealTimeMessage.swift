/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public class SystemRealTimeMessage: Message {

    public enum MessageType: UInt8 {
        case clock          = 0xF8
        case start          = 0xFA
        case `continue`     = 0xFB
        case stop           = 0xFC
        case activeSense    = 0xFE
        case reset          = 0xFF
    }

    public var type: MessageType {
        get {
            MessageType(rawValue: statusByte)!
        }
        set {
            statusByte = newValue.rawValue
        }
    }

    init(timeStamp: MIDITimeStamp, type: MessageType) {
        super.init(timeStamp: timeStamp, statusByte: type.rawValue)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: Message overrides

    public override var messageType: TypeMask {
        switch type {
        case .clock:        return .clock
        case .start:        return .start
        case .continue:     return .continue
        case .stop:         return .stop
        case .activeSense:  return .activeSense
        case .reset:        return .reset
        }
    }

    public override var typeForDisplay: String {
        switch type {
        case .clock:
            return NSLocalizedString("Clock", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Clock event")
        case .start:
            return NSLocalizedString("Start", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Start event")
        case .continue:
            return NSLocalizedString("Continue", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Continue event")
        case .stop:
            return NSLocalizedString("Stop", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Stop event")
        case .activeSense:
            return NSLocalizedString("Active Sense", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Active Sense event")
        case .reset:
            return NSLocalizedString("Reset", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Reset event")
        }
    }

}
