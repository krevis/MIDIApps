/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CoreMIDI
import CoreAudio

@objc public class SMMessage: NSObject, NSCoding {

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

    @objc public init(timeStamp: MIDITimeStamp, statusByte: UInt8) {
        self.timeStampWasZeroWhenReceived = timeStamp == 0
        self.timeStamp = timeStampWasZeroWhenReceived ? AudioGetCurrentHostTime() : timeStamp
        self.timeBase = SMMessageTimeBase.current
        self.statusByte = statusByte
        super.init()
    }

    @objc public required init?(coder: NSCoder) {
        if coder.containsValue(forKey: "timeStampInNanos") {
            let nanos = coder.decodeInt64(forKey: "timeStampInNanos")
            self.timeStamp = AudioConvertNanosToHostTime(UInt64(nanos))
            timeStampWasZeroWhenReceived = coder.decodeBool(forKey: "timeStampWasZeroWhenReceived")
        }
        else {
            // fall back to old, inaccurate method
            // (we stored HostTime but not the ratio to convert it to nanoseconds)
            self.timeStamp = MIDITimeStamp(coder.decodeInt64(forKey: "timeStamp"))
            self.timeStampWasZeroWhenReceived = self.timeStamp == 0
        }

        guard let timeBase = coder.decodeObject(forKey: "timeBase") as? SMMessageTimeBase else { return nil }
        self.timeBase = timeBase

        let status = coder.decodeInteger(forKey: "statusByte")
        guard (0x80...0xFF).contains(status) else { return nil }
        self.statusByte = UInt8(status)

        if let endpointName = coder.decodeObject(forKey: "originatingEndpoint") as? String {
            self.originatingEndpointName = endpointName
        }

        super.init()
    }

    public func encode(with coder: NSCoder) {
        let nanos = AudioConvertHostTimeToNanos(timeStamp)
        coder.encode(Int64(nanos), forKey: "timeStampInNanos")
        coder.encode(timeStampWasZeroWhenReceived, forKey: "timeStampWasZeroWhenReceived")

        let time = timeStampWasZeroWhenReceived ? 0 : timeStamp
        coder.encode(Int64(time), forKey: "timeStamp")
            // for backwards compatibility

        coder.encode(timeBase, forKey: "timeBase")
        coder.encode(Int(statusByte), forKey: "statusByte")
        coder.encode(originatingEndpointForDisplay, forKey: "originatingEndpoint")
    }

    public let timeStamp: MIDITimeStamp
    public internal(set) var statusByte: UInt8

    // Type of this message (mask containing at most one value)
    public var messageType: TypeMask {
        fatalError("Must be implemented by subclass")   // TODO Maybe this should be a protocol, then
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
        if let otherData = otherData {
            return statusByteData + otherData
        }
        else {
            return statusByteData
        }
    }

    @objc public var originatingEndpoint: SMEndpoint? {
        didSet {
            if oldValue != originatingEndpoint {
                originatingEndpointName = nil
            }
        }
    }

    // Display methods

    public var timeStampForDisplay: String {
        let displayZero = timeStampWasZeroWhenReceived && UserDefaults.standard.bool(forKey: Self.expertModePreferenceKey)
        let displayTimeStamp = displayZero ? 0 : timeStamp

        switch TimeFormattingOption.default {
        case .hostTimeInteger:
            return String(format: "%llu", displayTimeStamp)

        case .hostTimeHexInteger:
            return String(format: "%016llX", displayTimeStamp)

        case .hostTimeNanoseconds:
            return String(format: "%llu", AudioConvertHostTimeToNanos(displayTimeStamp))

        case .hostTimeSeconds:
            return String(format: "%.3lf", Double(AudioConvertHostTimeToNanos(displayTimeStamp)) / 1.0e9)

        case .clockTime:
            if displayZero {
                return "0"
            }
            else {
                let timeStampInNanos = AudioConvertHostTimeToNanos(displayTimeStamp)
                let hostTimeBaseInNanos = timeBase.hostTimeInNanos
                let timeDeltaInNanos = Double(timeStampInNanos) - Double(hostTimeBaseInNanos) // may be negative!
                let timeStampInterval = timeDeltaInNanos / 1.0e9
                let date = Date(timeIntervalSinceReferenceDate: timeBase.timeInterval + timeStampInterval)
                return Self.timeStampDateFormatter.string(from: date)
            }
        }

    }

    public var typeForDisplay: String {
        // Subclasses may override
        let typeName = NSLocalizedString("Unknown", tableName: "SnoizeMIDI", bundle: SMBundleForObject(self), comment: "displayed type of unknown MIDI status byte")
        let status = String(format: "%02X", statusByte)
        return "\(typeName) ($\(status))"
    }

    public var channelForDisplay: String {
        // Subclasses may override
        return ""
    }

    public var dataForDisplay: String {
        return SMMessage.formatData(otherData)
    }

    public var expertDataForDisplay: String {
        return SMMessage.formatExpertStatusByte(statusByte, otherData: otherData)
    }

    public var originatingEndpointForDisplay: String {
        if let endpoint = originatingEndpoint {
            let fromOrTo = endpoint is SMSourceEndpoint ? SMMessage.fromString : SMMessage.toString
            return "\(fromOrTo) \(endpoint.alwaysUniqueName ?? "")"
        }
        else if let endpointName = originatingEndpointName {
            return endpointName
        }
        else {
            return ""
        }
    }

    public static func prepareToEncodeWithObjCCompatibility(archiver: NSKeyedArchiver) {
        archiver.setClassName("SMMessage", for: SMMessage.self)
        archiver.setClassName("SMVoiceMessage", for: SMVoiceMessage.self)
        archiver.setClassName("SMSystemCommonMessage", for: SMSystemCommonMessage.self)
        archiver.setClassName("SMSystemRealTimeMessage", for: SMSystemRealTimeMessage.self)
        archiver.setClassName("SMSystemExclusiveMessage", for: SMSystemExclusiveMessage.self)
        archiver.setClassName("SMInvalidMessage", for: SMInvalidMessage.self)
        archiver.setClassName("SMMessageTimeBase", for: SMMessageTimeBase.self)
    }

    public static func prepareToDecodeWithObjCCompatibility(unarchiver: NSKeyedUnarchiver) {
        unarchiver.setClass(SMMessage.self, forClassName: "SMMessage")
        unarchiver.setClass(SMVoiceMessage.self, forClassName: "SMVoiceMessage")
        unarchiver.setClass(SMSystemCommonMessage.self, forClassName: "SMSystemCommonMessage")
        unarchiver.setClass(SMSystemRealTimeMessage.self, forClassName: "SMSystemRealTimeMessage")
        unarchiver.setClass(SMSystemExclusiveMessage.self, forClassName: "SMSystemExclusiveMessage")
        unarchiver.setClass(SMInvalidMessage.self, forClassName: "SMInvalidMessage")
        unarchiver.setClass(SMMessageTimeBase.self, forClassName: "SMMessageTimeBase")
    }

    // MARK: Private

    private var timeBase: SMMessageTimeBase
    private var originatingEndpointName: String?
    private var timeStampWasZeroWhenReceived: Bool

    private static let fromString = NSLocalizedString("From", tableName: "SnoizeMIDI", bundle: SMBundleForObject(SMMessage.self), comment: "Prefix for endpoint name when it's a source")
    private static let toString = NSLocalizedString("To", tableName: "SnoizeMIDI", bundle: SMBundleForObject(SMMessage.self), comment: "Prefix for endpoint name when it's a destination")

    private static var timeStampDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

}

@objc extension SMMessage /* Formatting */ {
    // TODO Move this all out to somewhere else

    @objc public enum NoteFormattingOption: Int {
        case decimal
        case hexadecimal
        case nameMiddleC3    // Middle C = 60 decimal = C3, aka "Yamaha"
        case nameMiddleC4    // Middle C = 60 decimal = C4, aka "Roland"

        static var `default`: Self {
            return Self(rawValue: UserDefaults.standard.integer(forKey: SMMessage.noteFormatPreferenceKey)) ?? .decimal
        }
    }

    @objc public enum ControllerFormattingOption: Int {
        case decimal
        case hexadecimal
        case name

        static var `default`: Self {
            return Self(rawValue: UserDefaults.standard.integer(forKey: SMMessage.controllerFormatPreferenceKey)) ?? .decimal
        }
    }

    @objc public enum DataFormattingOption: Int {
        case decimal
        case hexadecimal

        static var `default`: Self {
            return Self(rawValue: UserDefaults.standard.integer(forKey: SMMessage.dataFormatPreferenceKey)) ?? .decimal
        }
    }

    @objc public enum TimeFormattingOption: Int {
        case hostTimeInteger
        case hostTimeNanoseconds
        case hostTimeSeconds
        case clockTime
        case hostTimeHexInteger

        static var `default`: Self {
            return Self(rawValue: UserDefaults.standard.integer(forKey: SMMessage.timeFormatPreferenceKey)) ?? .hostTimeInteger
        }
    }

    // Preferences keys
    public static let noteFormatPreferenceKey = "SMNoteFormat"
    public static let controllerFormatPreferenceKey = "SMControllerFormat"
    public static let dataFormatPreferenceKey = "SMDataFormat"
    public static let timeFormatPreferenceKey = "SMTimeFormat"
    public static let expertModePreferenceKey = "SMExpertMode"
    public static let programChangeBaseIndexPreferenceKey = "SMProgramChangeBaseIndex"

    public static func formatNoteNumber(_ noteNumber: UInt8) -> String {
        return formatNoteNumber(noteNumber, usingOption: NoteFormattingOption.default)
    }

    public static func formatNoteNumber(_ noteNumber: UInt8, usingOption option: NoteFormattingOption) -> String {
        switch option {
        case .decimal:
            return "\(noteNumber)"
        case .hexadecimal:
            return String(format: "$%02X", Int(noteNumber))
        case .nameMiddleC3:
            // Middle C ==  60 == "C3", so base == 0 == "C-2"
            return formatNoteNumber(noteNumber, baseOctave: -2)
        case .nameMiddleC4:
            // Middle C == 60 == "C2", so base == 0 == "C-1"
            return formatNoteNumber(noteNumber, baseOctave: -1)
        }
    }

    public static func formatControllerNumber(_ controllerNumber: UInt8) -> String {
        return formatControllerNumber(controllerNumber, usingOption: ControllerFormattingOption.default)
    }

    public static func formatControllerNumber(_ controllerNumber: UInt8, usingOption option: ControllerFormattingOption) -> String {
        switch option {
        case .decimal:
            return "\(controllerNumber)"
        case .hexadecimal:
            return String(format: "$%02X", Int(controllerNumber))
        case .name:
            return Self.controllerNames[Int(controllerNumber)]
        }
    }

    public static func formatProgramNumber(_ programNumber: UInt8) -> String {
        switch DataFormattingOption.default {
        case .decimal:
            let baseIndex = UserDefaults.standard.integer(forKey: Self.programChangeBaseIndexPreferenceKey)
            return "\(baseIndex + Int(programNumber))"
        case .hexadecimal:
            return String(format: "$%02X", Int(programNumber))
        }
    }

    public static func formatData(_ data: Data?) -> String {
        guard let data = data else { return "" }
        return data.map({ formatDataByte($0, usingOption: DataFormattingOption.default) }).joined(separator: " ")
    }

    public static func formatDataByte(_ dataByte: UInt8) -> String {
        return formatDataByte(dataByte, usingOption: DataFormattingOption.default)
    }

    public static func formatDataByte(_ dataByte: UInt8, usingOption option: DataFormattingOption) -> String {
        switch option {
        case .decimal:
            return "\(dataByte)"
        case .hexadecimal:
            return String(format: "$%02X", dataByte)
        }
    }

    public static func formatSignedDataBytes(_ byte0: UInt8, _ byte1: UInt8) -> String {
        return formatSignedDataBytes(byte0, byte1, usingOption: DataFormattingOption.default)
    }

    public static func formatSignedDataBytes(_ byte0: UInt8, _ byte1: UInt8, usingOption option: DataFormattingOption) -> String {
        // Combine two 7-bit values into one 14-bit value. Treat the result as signed, if displaying as decimal; 0x2000 is the center.
        let value: Int = Int(byte0) + (Int(byte1) << 7)

        switch option {
        case .decimal:
            return "\(value - 0x2000)"
        case .hexadecimal:
            return String(format: "$%04X", value)
        }
    }

    public static func formatLength(_ length: Int) -> String {
        return formatLength(length, usingOption: DataFormattingOption.default)
    }

    public static func formatLength(_ length: Int, usingOption option: DataFormattingOption) -> String {
        switch option {
        case .decimal:
            return "\(length)"
        case .hexadecimal:
            return String(format: "$%lX", length)
        }
    }

    public static func nameForManufacturerIdentifier(_ manufacturerIdentifierData: Data) -> String {
        return manufacturerNamesByHexIdentifier[manufacturerIdentifierData.lowercaseHexString]
            ?? NSLocalizedString("Unknown Manufacturer", tableName: "SnoizeMIDI", bundle: SMBundleForObject(SMMessage.self), comment: "unknown manufacturer name")
    }

    // MARK: Private

    private static func formatExpertStatusByte(_ statusByte: UInt8, otherData: Data?) -> String {
        var result = String(format: "%02X", statusByte)

        if let data = otherData, !data.isEmpty {
            for byte in data[data.startIndex ..< min(data.startIndex + 31, data.endIndex)] {
                result += String(format: " %02X", byte)
            }
            if data.count > 31 {
                result += "…"
            }
        }

        return result
    }

    private static func formatNoteNumber(_ noteNumber: UInt8, baseOctave: Int) -> String {
        // noteNumber 0 is note C in octave provided (should be -2 or -1)
        let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let noteName = noteNames[Int(noteNumber) % 12]
        return "\(noteName)\(baseOctave + Int(noteNumber) / 12)"
    }

    private static var controllerNames: [String] = {
        // It's lame that property lists must have keys which are strings. We would prefer an integer, in this case.
        // We could create a new string for the controllerNumber and look that up in the dictionary, but that gets expensive to do all the time.
        // Instead, we just scan through the dictionary once, and build an array, which is quicker to index into.

        let bundle = SMBundleForObject(SMMessage.self)  // Note: SMBundleForObject(self) returns the Swift bundle
        var controllerNamesByNumberString: NSDictionary?
        if let url = bundle.url(forResource: "ControllerNames", withExtension: "plist") {
            controllerNamesByNumberString = NSDictionary(contentsOf: url)
        }

        let unknownNameFormat = NSLocalizedString("Controller %u", tableName: "SnoizeMIDI", bundle: bundle, comment: "format of unknown controller")

        return (0 ..< 128).map { controllerIndex in
            controllerNamesByNumberString?.object(forKey: "\(controllerIndex)") as? String
                ?? String(format: unknownNameFormat, controllerIndex)
        }
    }()

    private static var manufacturerNamesByHexIdentifier: [String: String] = {
        var manufacturerNames: [String: String] = [:]
        let bundle = SMBundleForObject(SMMessage.self)  // Note: SMBundleForObject(self) returns the Swift bundle
        if let url = bundle.url(forResource: "ManufacturerNames", withExtension: "plist"),
           let plist = NSDictionary(contentsOf: url) as? [String: String] {
            manufacturerNames = plist
        }
        return manufacturerNames
    }()

}
