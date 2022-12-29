/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public struct MessageFormatter {

    public enum NoteFormattingOption: Int {
        case decimal
        case hexadecimal
        case nameMiddleC3    // Middle C = 60 decimal = C3, aka "Yamaha"
        case nameMiddleC4    // Middle C = 60 decimal = C4, aka "Roland"

        static var `default`: Self {
            return Self(rawValue: UserDefaults.standard.integer(forKey: MessageFormatter.noteFormatPreferenceKey)) ?? .decimal
        }
    }

    public enum ControllerFormattingOption: Int {
        case decimal
        case hexadecimal
        case name

        static var `default`: Self {
            return Self(rawValue: UserDefaults.standard.integer(forKey: MessageFormatter.controllerFormatPreferenceKey)) ?? .decimal
        }
    }

    public enum DataFormattingOption: Int {
        case decimal
        case hexadecimal

        static var `default`: Self {
            return Self(rawValue: UserDefaults.standard.integer(forKey: MessageFormatter.dataFormatPreferenceKey)) ?? .decimal
        }
    }

    public enum TimeFormattingOption: Int {
        case hostTimeInteger
        case hostTimeNanoseconds
        case hostTimeSeconds
        case clockTime
        case hostTimeHexInteger

        static var `default`: Self {
            return Self(rawValue: UserDefaults.standard.integer(forKey: MessageFormatter.timeFormatPreferenceKey)) ?? .hostTimeInteger
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
        guard let data else { return "" }
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
            ?? NSLocalizedString("Unknown Manufacturer", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "unknown manufacturer name")
    }

    // MARK: Internal

    static func formatExpertStatusByte(_ statusByte: UInt8, otherData: Data?) -> String {
        var result = String(format: "%02X", statusByte)

        let maxOtherDataCount = 255
        if let data = otherData, !data.isEmpty {
            for byte in data[data.startIndex ..< min(data.startIndex + maxOtherDataCount, data.endIndex)] {
                result += String(format: " %02X", byte)
            }
            if data.count > maxOtherDataCount {
                result += "…"
            }
        }

        return result
    }

    static func formatNoteNumber(_ noteNumber: UInt8, baseOctave: Int) -> String {
        // noteNumber 0 is note C in octave provided (should be -2 or -1)
        let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let noteName = noteNames[Int(noteNumber) % 12]
        return "\(noteName)\(baseOctave + Int(noteNumber) / 12)"
    }

    // MARK: Private

    private static var controllerNames: [String] = {
        // It's lame that property lists must have keys which are strings. We would prefer an integer, in this case.
        // We could create a new string for the controllerNumber and look that up in the dictionary, but that gets expensive to do all the time.
        // Instead, we just scan through the dictionary once, and build an array, which is quicker to index into.

        var controllerNamesByNumberString: [String: String] = [:]
        if let url = Bundle.snoizeMIDI.url(forResource: "ControllerNames", withExtension: "plist"),
           let plist = NSDictionary(contentsOf: url) as? [String: String] {
            controllerNamesByNumberString = plist
        }

        let unknownNameFormat = NSLocalizedString("Controller %u", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "format of unknown controller")

        return (0 ..< 128).map {
            controllerNamesByNumberString["\($0)"] ?? String(format: unknownNameFormat, $0)
        }
    }()

    private static var manufacturerNamesByHexIdentifier: [String: String] = {
        var manufacturerNames: [String: String] = [:]
        if let url = Bundle.snoizeMIDI.url(forResource: "ManufacturerNames", withExtension: "plist"),
           let plist = NSDictionary(contentsOf: url) as? [String: String] {
            manufacturerNames = plist
        }
        return manufacturerNames
    }()

}
