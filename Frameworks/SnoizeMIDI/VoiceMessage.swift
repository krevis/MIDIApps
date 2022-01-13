/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class VoiceMessage: Message {

    public enum Status: UInt8 {
        case noteOff = 0x80
        case noteOn = 0x90
        case aftertouch = 0xA0
        case control = 0xB0
        case program = 0xC0
        case channelPressure = 0xD0
        case pitchWheel = 0xE0

        var otherDataLength: Int {
            switch self {
            case .program, .channelPressure:
                return 1
            case .noteOff, .noteOn, .aftertouch, .control, .pitchWheel:
                return 2
            }
        }
    }

    public var status: Status {
        get { Status(rawValue: statusByte & 0xF0)! }
        set { statusByte = newValue.rawValue | UInt8(channel - 1) }
    }

    // NOTE Channel is 1-16, not 0-15
    public var channel: Int {
        get { Int(statusByte & 0x0F) + 1 }
        set {
            guard (1...16).contains(newValue) else { fatalError() }
            statusByte = status.rawValue | UInt8(newValue - 1)
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

    public init(timeStamp: MIDITimeStamp, statusByte: UInt8, data: [UInt8]) {
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
        super.init(timeStamp: timeStamp, statusByte: statusByte)
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

    public struct ChannelMask: OptionSet {
        public let rawValue: Int
        public typealias RawValue = Int // swiftlint:disable:this nesting

        public init(rawValue: Self.RawValue) {
            self.rawValue = rawValue
        }

        // Note: Channel must be in range 1-16
        public init(channel: Int) {
            guard (1...16).contains(channel) else { fatalError() }
            self.rawValue = 1 << (channel - 1)
        }

        public static let channel1 = Self(rawValue: 1 << 0)
        public static let channel2 = Self(rawValue: 1 << 1)
        public static let channel3 = Self(rawValue: 1 << 2)
        public static let channel4 = Self(rawValue: 1 << 3)
        public static let channel5 = Self(rawValue: 1 << 4)
        public static let channel6 = Self(rawValue: 1 << 5)
        public static let channel7 = Self(rawValue: 1 << 6)
        public static let channel8 = Self(rawValue: 1 << 7)
        public static let channel9 = Self(rawValue: 1 << 8)
        public static let channel10 = Self(rawValue: 1 << 9)
        public static let channel11 = Self(rawValue: 1 << 10)
        public static let channel12 = Self(rawValue: 1 << 11)
        public static let channel13 = Self(rawValue: 1 << 12)
        public static let channel14 = Self(rawValue: 1 << 13)
        public static let channel15 = Self(rawValue: 1 << 14)
        public static let channel16 = Self(rawValue: 1 << 15)

        public static let all = Self(rawValue: (1 << 16) - 1)
    }

    public func matchesChannelMask(_ mask: ChannelMask) -> Bool {
        return mask.contains(ChannelMask(channel: channel))
    }

    // MARK: Private

    private var dataBytes: (UInt8, UInt8) = (0, 0)

    // MARK: Message overrides

    public override var messageType: TypeMask {
        switch status {
        case .noteOff:          return .noteOff
        case .noteOn:           return .noteOn
        case .aftertouch:       return .aftertouch
        case .control:          return .control
        case .program:          return .program
        case .channelPressure:  return .channelPressure
        case .pitchWheel:       return .pitchWheel
        }
    }

    public override var otherDataLength: Int {
        status.otherDataLength
    }

    public override var otherData: Data? {
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

    public override var typeForDisplay: String {
        switch status {
        case .noteOn:
            // In the MIDI specification, Note On with 0 velocity is defined to have
            // the exact same meaning as Note Off (with 0 velocity).
            // In non-expert mode, show these events as Note Offs.
            // In expert mode, show them as Note Ons.
            if dataBytes.1 != 0 || UserDefaults.standard.bool(forKey: MessageFormatter.expertModePreferenceKey) {
                return NSLocalizedString("Note On", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Note On event")
            }
            else {
                fallthrough // display as note off
            }

        case .noteOff:
            return NSLocalizedString("Note Off", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Note Off event")

        case .aftertouch:
            return NSLocalizedString("Aftertouch", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Aftertouch (poly pressure) event")

        case .control:
            return NSLocalizedString("Control", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Control event")

        case .program:
            return NSLocalizedString("Program", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Program event")

        case .channelPressure:
            return NSLocalizedString("Channel Pressure", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Channel Pressure (aftertouch) event")

        case .pitchWheel:
            return NSLocalizedString("Pitch Wheel", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Pitch Wheel event")
        }
    }

    public override var channelForDisplay: String {
        "\(channel)"
    }

    public override var dataForDisplay: String {
        switch status {
        case .noteOff, .noteOn, .aftertouch:
            return MessageFormatter.formatNoteNumber(dataBytes.0) + "\t" + MessageFormatter.formatDataByte(dataBytes.1)

        case .control:
            return MessageFormatter.formatControllerNumber(dataBytes.0) + "\t" + MessageFormatter.formatDataByte(dataBytes.1)

        case .program:
            return MessageFormatter.formatProgramNumber(dataBytes.0)

        case .channelPressure:
            return super.dataForDisplay

        case .pitchWheel:
            return MessageFormatter.formatSignedDataBytes(dataBytes.0, dataBytes.1)
        }
    }

}
