/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
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
            return String(localized: "Clock", comment: "displayed type of Clock event")
        case .start:
            return String(localized: "Start", comment: "displayed type of Start event")
        case .continue:
            return String(localized: "Continue", comment: "displayed type of Continue event")
        case .stop:
            return String(localized: "Stop", comment: "displayed type of Stop event")
        case .activeSense:
            return String(localized: "Active Sense", comment: "displayed type of Active Sense event")
        case .reset:
            return String(localized: "Reset", comment: "displayed type of Reset event")
        }
    }

}
