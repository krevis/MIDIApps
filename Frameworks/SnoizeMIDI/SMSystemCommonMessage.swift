/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class SMSystemCommonMessage: SMMessage {

    // TODO There should be associated data on the type to store the bytes, probably
    public enum MessageType: UInt8 {
        case timeCodeQuarterFrame   = 0xF1
        case songPositionPointer    = 0xF2
        case songSelect             = 0xF3
        case tuneRequest            = 0xF6

        var otherDataLength: Int {
            switch self {
            case .timeCodeQuarterFrame: return 1
            case .songPositionPointer:  return 2
            case .songSelect:           return 1
            case .tuneRequest:          return 0
            }
        }
    }

    public var type: MessageType {
        get {
            MessageType(rawValue: statusByte)!
        }
        set {
            self.setStatusByte(newValue.rawValue)
        }
    }

    public var dataByte1: UInt8 {
        get { dataBytes.0 }
        set {
            guard (0..<128).contains(newValue) else { fatalError() }
            dataBytes.0 = newValue
        }
    }

    public var dataByte2: UInt8 {
        get { dataBytes.1 }
        set {
            guard (0..<128).contains(newValue) else { fatalError() }
            dataBytes.1 = newValue
        }
    }

    init(timeStamp: MIDITimeStamp, type: MessageType, data: [UInt8]) {
        if data.count > 0 {
            let byte0 = data[data.startIndex]
            guard (0..<128).contains(byte0) else { fatalError() }
            dataBytes.0 = byte0
            if data.count > 1 {
                let byte1 = data[data.startIndex + 1]
                guard (0..<128).contains(byte1) else { fatalError() }
                dataBytes.1 = byte1
            }
        }
        super.init(timeStamp: timeStamp, statusByte: type.rawValue)
    }

    required init?(coder: NSCoder) {
        var length = 0
        if let decodedBytes = coder.decodeBytes(forKey: "dataBytes", returnedLength: &length),
           length == 2 {
            guard (0..<128).contains(decodedBytes[0]) else { fatalError() }
            guard (0..<128).contains(decodedBytes[1]) else { fatalError() }
            dataBytes.0 = decodedBytes[0]
            dataBytes.1 = decodedBytes[1]
        }
        else {
            return nil
        }
        super.init(coder: coder)
    }

    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        var bytes = [dataBytes.0, dataBytes.1]
        coder.encodeBytes(&bytes, length: 2, forKey: "dataBytes")
    }

    // MARK: Private

    private var dataBytes: (UInt8, UInt8) = (0, 0)

    // MARK: SMMessage overrides

    public override var messageType: SMMessageType {
        switch type {
        case .timeCodeQuarterFrame: return SMMessageTypeTimeCode
        case .songPositionPointer:  return SMMessageTypeSongPositionPointer
        case .songSelect:           return SMMessageTypeSongSelect
        case .tuneRequest:          return SMMessageTypeTuneRequest
        }
    }

    public override var otherDataLength: Int {
        type.otherDataLength
    }

    public override var otherData: Data! {
        if otherDataLength == 2 {
            return Data([dataBytes.0, dataBytes.1])
        }
        else if otherDataLength == 1 {
            return Data([dataBytes.0])
        }
        else {
            return Data()
        }
    }

    public override var typeForDisplay: String! {
        switch type {
        case .timeCodeQuarterFrame:
            return NSLocalizedString("MTC Quarter Frame", tableName: "SnoizeMIDI", bundle: SMBundleForObject(self), comment: "displayed type of MTC Quarter Frame event")
        case .songPositionPointer:
            return NSLocalizedString("Song Position Pointer", tableName: "SnoizeMIDI", bundle: SMBundleForObject(self), comment: "displayed type of Song Position Pointer event")
        case .songSelect:
            return NSLocalizedString("Song Select", tableName: "SnoizeMIDI", bundle: SMBundleForObject(self), comment: "displayed type of Song Select event")
        case .tuneRequest:
            return NSLocalizedString("Tune Request", tableName: "SnoizeMIDI", bundle: SMBundleForObject(self), comment: "displayed type of Tune Request event")
        }
    }

}
