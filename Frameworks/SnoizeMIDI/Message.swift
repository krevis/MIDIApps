/*
 Copyright (c) 2001-2022, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI
import CoreAudio

public class Message: NSObject, NSCoding {

    public struct TypeMask: OptionSet {
        public let rawValue: Int
        public typealias RawValue = Int // swiftlint:disable:this nesting

        public init(rawValue: Self.RawValue) {
            self.rawValue = rawValue
        }

        // Voice messages
        public static let noteOn                = Self(rawValue: 1 << 0)
        public static let noteOff               = Self(rawValue: 1 << 1)
        public static let aftertouch            = Self(rawValue: 1 << 2)
        public static let control               = Self(rawValue: 1 << 3)
        public static let program               = Self(rawValue: 1 << 4)
        public static let channelPressure       = Self(rawValue: 1 << 5)
        public static let pitchWheel            = Self(rawValue: 1 << 6)

        // System common messages
        public static let timeCode              = Self(rawValue: 1 << 7)
        public static let songPositionPointer   = Self(rawValue: 1 << 8)
        public static let songSelect            = Self(rawValue: 1 << 9)
        public static let tuneRequest           = Self(rawValue: 1 << 10)

        // Real time messages
        public static let clock                 = Self(rawValue: 1 << 11)
        public static let start                 = Self(rawValue: 1 << 12)
        public static let stop                  = Self(rawValue: 1 << 13)
        public static let `continue`            = Self(rawValue: 1 << 14)
        public static let activeSense           = Self(rawValue: 1 << 15)
        public static let reset                 = Self(rawValue: 1 << 16)

        // System exclusive
        public static let systemExclusive       = Self(rawValue: 1 << 17)

        // Invalid
        public static let invalid               = Self(rawValue: 1 << 18)

        // Groups
        public static let all                   = Self(rawValue: (1 << 19) - 1)
    }

    public init(timeStamp: MIDITimeStamp, statusByte: UInt8) {
        self.timeStampWasZeroWhenReceived = timeStamp == 0
        self.hostTimeStamp = timeStampWasZeroWhenReceived ? SMGetCurrentHostTime() : timeStamp
        self.clockTimeStamp = Date.timeIntervalSinceReferenceDate
        self.timeBase = nil
        self.statusByte = statusByte
        super.init()
    }

    public required init?(coder: NSCoder) {
        if coder.containsValue(forKey: "timeStampInNanos") {
            let nanos = UInt64(bitPattern: coder.decodeInt64(forKey: "timeStampInNanos"))
            self.hostTimeStamp = SMConvertNanosToHostTime(nanos)
            timeStampWasZeroWhenReceived = coder.decodeBool(forKey: "timeStampWasZeroWhenReceived")
        }
        else {
            // fall back to old, inaccurate method
            // (we stored HostTime but not the ratio to convert it to nanoseconds)
            self.hostTimeStamp = MIDITimeStamp(bitPattern: coder.decodeInt64(forKey: "timeStamp"))
            self.timeStampWasZeroWhenReceived = self.hostTimeStamp == 0
        }

        let timeBase: MessageTimeBase? = coder.decodeObject(forKey: "timeBase") as? MessageTimeBase
            // May be nil, in favor of clockTimeStamp.

        let clockTimeStampOrZero = coder.decodeDouble(forKey: "clockTimeStamp")
        let clockTimeStamp: TimeInterval? = (clockTimeStampOrZero != 0 ? clockTimeStampOrZero : nil)

        guard timeBase != nil || clockTimeStamp != nil else { return nil }
        self.timeBase = timeBase
        self.clockTimeStamp = clockTimeStamp

        let status = coder.decodeInteger(forKey: "statusByte")
        guard (0x80...0xFF).contains(status) else { return nil }
        self.statusByte = UInt8(status)

        if let endpointName = coder.decodeObject(forKey: "originatingEndpoint") as? String {
            self.originatingEndpointName = endpointName
        }

        super.init()
    }

    public func encode(with coder: NSCoder) {
        let nanos = SMConvertHostTimeToNanos(hostTimeStamp)
        coder.encode(Int64(bitPattern: nanos), forKey: "timeStampInNanos")
        coder.encode(timeStampWasZeroWhenReceived, forKey: "timeStampWasZeroWhenReceived")

        let time = timeStampWasZeroWhenReceived ? 0 : hostTimeStamp
        coder.encode(Int64(bitPattern: time), forKey: "timeStamp")
            // for backwards compatibility

        coder.encode(timeBase ?? MessageTimeBase.current, forKey: "timeBase")
            // for backwards compatibility

        coder.encode(Int(statusByte), forKey: "statusByte")
        coder.encode(originatingEndpointForDisplay, forKey: "originatingEndpoint")

        if let clockTimeStamp {
            coder.encode(clockTimeStamp, forKey: "clockTimeStamp")
        }
    }

    public let hostTimeStamp: MIDITimeStamp     // in host time units
    public let clockTimeStamp: TimeInterval?    // like Date.timeIntervalSinceReferenceDate
    public internal(set) var statusByte: UInt8

    // Type of this message (mask containing at most one value)
    public var messageType: TypeMask {
        fatalError("Must be implemented by subclass")
    }

    public func matchesMessageTypeMask(_ mask: TypeMask) -> Bool {
        mask.contains(messageType)
    }

    // Length of data after the status byte
    public var otherDataLength: Int {
        // Subclasses must override if they have other data
        0
    }

    public var otherData: Data? {
        // Subclasses must override if they have other data
        nil
    }

    // All data including status byte and otherData
    public var fullData: Data {
        let statusByteData = Data([statusByte])
        if let otherData {
            return statusByteData + otherData
        }
        else {
            return statusByteData
        }
    }

    public var originatingEndpoint: Endpoint? {
        didSet {
            if oldValue != originatingEndpoint {
                originatingEndpointName = nil
            }
        }
    }

    // Display methods

    public var timeStampForDisplay: String {
        let displayZero = timeStampWasZeroWhenReceived && UserDefaults.standard.bool(forKey: MessageFormatter.expertModePreferenceKey)
        let displayedHostTimeStamp = displayZero ? 0 : hostTimeStamp

        switch MessageFormatter.TimeFormattingOption.default {
        case .hostTimeInteger:
            return String(format: "%llu", displayedHostTimeStamp)

        case .hostTimeHexInteger:
            return String(format: "%016llX", displayedHostTimeStamp)

        case .hostTimeNanoseconds:
            return String(format: "%llu", SMConvertHostTimeToNanos(displayedHostTimeStamp))

        case .hostTimeSeconds:
            return String(format: "%.3lf", Double(SMConvertHostTimeToNanos(displayedHostTimeStamp)) / 1.0e9)

        case .clockTime:
            if displayZero {
                return "0"
            }
            else if let clockTimeStamp {
                // New way: Use the actual clock timestamp that we saved when the message was created
                let date = Date(timeIntervalSinceReferenceDate: clockTimeStamp)
                return Self.timeStampDateFormatter.string(from: date)
            }
            else if let timeBase {
                // We have to use the older, mistaken method: MessageTimeBase contains an offset from host time to clock time.
                let timeStampInNanos = SMConvertHostTimeToNanos(hostTimeStamp)
                let hostTimeBaseInNanos = timeBase.hostTimeInNanos
                let timeDeltaInNanos = Double(timeStampInNanos) - Double(hostTimeBaseInNanos) // may be negative!
                let timeStampInterval = timeDeltaInNanos / 1.0e9
                let date = Date(timeIntervalSinceReferenceDate: timeBase.timeInterval + timeStampInterval)
                return Self.timeStampDateFormatter.string(from: date)
            }
            else {  // Shouldn't happen
                return ""
            }
        }

    }

    public var typeForDisplay: String {
        // Subclasses may override
        let typeName = NSLocalizedString("Unknown", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of unknown MIDI status byte")
        let status = String(format: "%02X", statusByte)
        return "\(typeName) ($\(status))"
    }

    public var channelForDisplay: String {
        // Subclasses may override
        return ""
    }

    public var dataForDisplay: String {
        return MessageFormatter.formatData(otherData)
    }

    public var expertDataForDisplay: String {
        return MessageFormatter.formatExpertStatusByte(statusByte, otherData: otherData)
    }

    public var originatingEndpointForDisplay: String {
        if let endpoint = originatingEndpoint {
            let fromOrTo = endpoint is Source ? Message.fromString : Message.toString
            return "\(fromOrTo) \(endpoint.displayName ?? "")"
        }
        else if let endpointName = originatingEndpointName {
            return endpointName
        }
        else {
            return ""
        }
    }

    public static func prepareToEncodeWithObjCCompatibility(archiver: NSKeyedArchiver) {
        archiver.setClassName("SMMessage", for: Message.self)
        archiver.setClassName("SMVoiceMessage", for: VoiceMessage.self)
        archiver.setClassName("SMSystemCommonMessage", for: SystemCommonMessage.self)
        archiver.setClassName("SMSystemRealTimeMessage", for: SystemRealTimeMessage.self)
        archiver.setClassName("SMSystemExclusiveMessage", for: SystemExclusiveMessage.self)
        archiver.setClassName("SMInvalidMessage", for: InvalidMessage.self)
        archiver.setClassName("SMMessageTimeBase", for: MessageTimeBase.self)
    }

    public static func prepareToDecodeWithObjCCompatibility(unarchiver: NSKeyedUnarchiver) {
        unarchiver.setClass(Message.self, forClassName: "SMMessage")
        unarchiver.setClass(VoiceMessage.self, forClassName: "SMVoiceMessage")
        unarchiver.setClass(SystemCommonMessage.self, forClassName: "SMSystemCommonMessage")
        unarchiver.setClass(SystemRealTimeMessage.self, forClassName: "SMSystemRealTimeMessage")
        unarchiver.setClass(SystemExclusiveMessage.self, forClassName: "SMSystemExclusiveMessage")
        unarchiver.setClass(InvalidMessage.self, forClassName: "SMInvalidMessage")
        unarchiver.setClass(MessageTimeBase.self, forClassName: "SMMessageTimeBase")
    }

    // MARK: Private

    private var originatingEndpointName: String?

    // FUTURE: Get rid of this. Only present for backwards compatibility in MIDI Monitor documents, to display timestamp as clock time.
    private var timeBase: MessageTimeBase?

    private var timeStampWasZeroWhenReceived: Bool

    private static let fromString = NSLocalizedString("From", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "Prefix for endpoint name when it's a source")
    private static let toString = NSLocalizedString("To", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "Prefix for endpoint name when it's a destination")

    private static var timeStampDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

}
