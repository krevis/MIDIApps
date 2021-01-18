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
        public static let voice = [ noteOn, noteOff, aftertouch, control, program, channelPressure, pitchWheel ]
        public static let noteOnAndOff = [ noteOn, noteOff ]
        public static let systemCommon = [ timeCode, songPositionPointer, songSelect, tuneRequest ]
        public static let realTime = [ clock, start, stop, `continue`, activeSense, reset ]
    }

    @objc public init(timeStamp: MIDITimeStamp, statusByte: UInt8) {
        self.timeStampWasZeroWhenReceived = timeStamp == 0
        self.timeStamp = timeStampWasZeroWhenReceived ? AudioGetCurrentHostTime() : timeStamp
        self.timeBase = SMMessageTimeBase.current()
        self.statusByte = statusByte
        super.init()
    }

    @objc public required init?(coder: NSCoder) {
        // TODO
        return nil
    }

    public func encode(with coder: NSCoder) {
        // TODO
    }

    public let timeStamp: MIDITimeStamp
    public internal(set) var statusByte: UInt8

    // Type of this message (mask containing at most one value)
    public var messageType: TypeMask {
        // TODO
        return []
    }

    public func matchesMessageTypeMask(_ mask: TypeMask) -> Bool {
        // TODO
        return false
    }

    // Length of data after the status byte
    public var otherDataLength: Int {
        // TODO
        return 0
    }

    public var otherData: Data? {
        return nil
    }

    // All data including status byte and otherData
    public var fullData: Data {
        // TODO
        return Data([statusByte])
    }

    @objc public var originatingEndpoint: SMEndpoint?
    // TODO

    // Display methods

    public var timeStampForDisplay: String {
        return "TODO"
    }

    public var channelForDisplay: String {
        return "TODO"
    }

    public var typeForDisplay: String {
        return "TODO"
    }

    public var dataForDisplay: String {
        return "TODO"
    }

    public var expertDataForDisplay: String {
        return "TODO"
    }

    public var originatingEndpointForDisplay: String {
        return "TODO"
    }

    // MARK: Private

    private var timeBase: SMMessageTimeBase
    private var originatingEndpointOrName: Any? // either SMEndpoint or NSString; TODO that's silly
    private var timeStampWasZeroWhenReceived: Bool

}

@objc extension SMMessage /* Formatting */ {
    // TODO Move this all out to somewhere else

    @objc public enum NoteFormattingOption: Int {
        case decimal
        case hexadecimal
        case nameMiddleC3    // Middle C = 60 decimal = C3, aka "Yamaha"
        case nameMiddleC4    // Middle C = 60 decimal = C4, aka "Roland"
    }

    @objc public enum ControllerFormattingOption: Int {
        case decimal
        case hexadecimal
        case name
    }

    @objc public enum DataFormattingOption: Int {
        case decimal
        case hexadecimal
    }

    @objc public enum TimeFormattingOption: Int {
        case hostTimeInteger
        case hostTimeNanoseconds
        case hostTimeSeconds
        case clockTime
        case hostTimeHexInteger
    }

    // Preferences keys
    public static let noteFormatPreferenceKey = "SMNoteFormat"
    public static let controllerFormatPreferenceKey = "SMControllerFormat"
    public static let dataFormatPreferenceKey = "SMDataFormat"
    public static let timeFormatPreferenceKey = "SMTimeFormat"
    public static let expertModePreferenceKey = "SMExpertMode"
    public static let programChangeBaseIndexPreferenceKey = "SMProgramChangeBaseIndex"

    public static func formatNoteNumber(_ noteNumber: UInt8) -> String {
        // TODO
        return ""
    }

    public static func formatNoteNumber(_ noteNumber: UInt8, usingOption option: NoteFormattingOption) -> String {
        // TODO
        return ""
    }

    public static func formatControllerNumber(_ controllerNumber: UInt8) -> String {
        // TODO
        return ""
    }

    public static func formatControllerNumber(_ controllerNumber: UInt8, usingOption option: ControllerFormattingOption) -> String {
        // TODO
        return ""
    }

    public static func nameForControllerNumber(_ controllerNumber: UInt8) -> String? {
        // TODO
        return nil
    }

    public static func formatProgramNumber(_ programNumber: UInt8) -> String {
        // TODO
        return ""
    }

    public static func formatData(_ data: Data) -> String {
        // TODO
        return ""
    }

    public static func formatDataByte(_ dataByte: UInt8) -> String {
        // TODO
        return ""
    }

    public static func formatDataByte(_ dataByte: UInt8, usingOption option: DataFormattingOption) -> String {
        // TODO
        return ""
    }

    public static func formatSignedDataBytes(_ byte0: UInt8, _ byte1: UInt8) -> String {
        // TODO
        return ""
    }

    public static func formatSignedDataBytes(_ byte0: UInt8, _ byte1: UInt8, usingOption option: DataFormattingOption) -> String {
        // TODO
        return ""
    }

    public static func formatLength(_ length: Int) -> String {
        // TODO
        return ""
    }

    public static func formatLength(_ length: Int, usingOption option: DataFormattingOption) -> String {
        // TODO
        return ""
    }

    public static func nameForManufacturerIdentifier(_ manufacturerIdentifierData: Data) -> String {
        // TODO or perhaps [UInt8]
        return ""
    }

}
