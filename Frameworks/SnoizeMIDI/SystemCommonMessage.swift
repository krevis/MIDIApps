/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public class SystemCommonMessage: Message {

    public enum Status: UInt8 {
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

    public var dataByte1: UInt8? {
        storage.dataByte1
    }

    public var dataByte2: UInt8? {
        storage.dataByte2
    }

    init(timeStamp: MIDITimeStamp, status: Status, data: [UInt8]) {
        guard let storage = Storage(status: status, data: data) else { fatalError() }
        self.storage = storage
        super.init(timeStamp: timeStamp, statusByte: status.rawValue)
    }

    required init?(coder: NSCoder) {
        var length = 0
        let statusByte = coder.decodeInteger(forKey: "statusByte")
        if let status = Status(rawValue: UInt8(statusByte)),
           let decodedBytes = coder.decodeBytes(forKey: "dataBytes", returnedLength: &length),
           length == 2 {
            var dataBytes: [UInt8] = []
            for dataByteIndex in 0 ..< status.otherDataLength {
                dataBytes.append(decodedBytes[dataByteIndex])
            }
            if let decodedStorage = Storage(status: status, data: dataBytes) {
                self.storage = decodedStorage
                super.init(coder: coder)
            }
            else {
                return nil
            }
        }
        else {
            return nil
        }
    }

    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        var bytes = [storage.dataByte1 ?? 0, storage.dataByte2 ?? 0]
        coder.encodeBytes(&bytes, length: 2, forKey: "dataBytes")
    }

    // MARK: Message overrides

    public override var messageType: TypeMask {
        storage.messageType
    }

    public override var otherDataLength: Int {
        storage.status.otherDataLength
    }

    public override var otherData: Data? {
        storage.otherData
    }

    public override var typeForDisplay: String {
        storage.typeForDisplay
    }

    // MARK: Private

    private enum Storage {
        case timeCodeQuarterFrame(UInt8)
        case songPositionPointer(UInt8, UInt8)
        case songSelect(UInt8)
        case tuneRequest

        init?(status: Status, data: [UInt8]) {
            guard status.otherDataLength == data.count else { return nil }
            if data.count > 0 {
                guard data[0] < 128 else { return nil }
            }
            if data.count > 1 {
                guard data[1] < 128 else { return nil }
            }

            switch status {
            case .timeCodeQuarterFrame: self = .timeCodeQuarterFrame(data[0])
            case .songPositionPointer:  self = .songPositionPointer(data[0], data[1])
            case .songSelect:           self = .songSelect(data[0])
            case .tuneRequest:          self = .tuneRequest
            }
        }

        var status: Status {
            switch self {
            case .timeCodeQuarterFrame: return .timeCodeQuarterFrame
            case .songPositionPointer:  return .songPositionPointer
            case .songSelect:           return .songSelect
            case .tuneRequest:          return .tuneRequest
            }
        }

        var dataByte1: UInt8? {
            switch self {
            case .timeCodeQuarterFrame(let byte1):      return byte1
            case .songPositionPointer(let byte1, _):    return byte1
            case .songSelect(let byte1):                return byte1
            case .tuneRequest:                          return nil
            }
        }

        var dataByte2: UInt8? {
            switch self {
            case .timeCodeQuarterFrame:                 return nil
            case .songPositionPointer(_, let byte2):    return byte2
            case .songSelect:                           return nil
            case .tuneRequest:                          return nil
            }
        }

        var otherData: Data {
            switch self {
            case .timeCodeQuarterFrame(let byte1):              return Data([byte1])
            case .songPositionPointer(let byte1, let byte2):    return Data([byte1, byte2])
            case .songSelect(let byte1):                        return Data([byte1])
            case .tuneRequest:                                  return Data()
            }
        }

        var messageType: TypeMask {
            switch self {
            case .timeCodeQuarterFrame: return .timeCode
            case .songPositionPointer:  return .songPositionPointer
            case .songSelect:           return .songSelect
            case .tuneRequest:          return .tuneRequest
            }
        }

        var typeForDisplay: String {
            switch self {
            case .timeCodeQuarterFrame:
                return NSLocalizedString("MTC Quarter Frame", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of MTC Quarter Frame event")
            case .songPositionPointer:
                return NSLocalizedString("Song Position Pointer", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Song Position Pointer event")
            case .songSelect:
                return NSLocalizedString("Song Select", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Song Select event")
            case .tuneRequest:
                return NSLocalizedString("Tune Request", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Tune Request event")
            }
        }
    }

    private var storage: Storage

}
