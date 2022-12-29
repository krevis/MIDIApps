/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class SystemExclusiveMessage: Message {

    // Init with data that does *not* include the starting 0xF0 or ending 0xF7.
    public init(timeStamp: MIDITimeStamp, data: Data) {
        self.data = data
        super.init(timeStamp: timeStamp, statusByte: 0xF0)
    }

    public required init?(coder: NSCoder) {
        if let data = coder.decodeObject(forKey: "data") as? Data {
            self.data = data
        }
        else {
            return nil
        }
        wasReceivedWithEOX = coder.decodeBool(forKey: "wasReceivedWithEOX")
        super.init(coder: coder)
    }

    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(data, forKey: "data")
        coder.encode(wasReceivedWithEOX, forKey: "wasReceivedWithEOX")
    }

    // MARK: Public

    // Data *without* the starting 0xF0 or ending 0xF7 (EOX).
    public var data: Data {
        didSet {
            cachedDataWithEOX = nil
        }
    }

    // Whether the message was received with an ending 0xF7 (EOX) or not.
    public var wasReceivedWithEOX = true

    // Data without the starting 0xF0, always with ending 0xF7.
    public override var otherData: Data? {
        if cachedDataWithEOX == nil {
            cachedDataWithEOX = data
            cachedDataWithEOX?.append(0xF7)
        }
        return cachedDataWithEOX
    }

    public override var otherDataLength: Int {
        data.count + 1  // Add a byte for the EOX at the end
    }

    // Data as received, without starting 0xF0. May or may not include 0xF7.
    public var receivedData: Data {
        wasReceivedWithEOX ? otherData! : data
    }

    public var receivedDataLength: Int {
        receivedData.count
    }

    // Data as received, with 0xF0 at start. May or may not include 0xF7.
    public var receivedDataWithStartByte: Data {
        dataByAddingStartByte(receivedData)
    }

    public var receivedDataWithStartByteLength: Int {
        receivedDataLength + 1
    }

    // Data with leading 0xF0 and ending 0xF7.
    public var fullMessageData: Data {
        dataByAddingStartByte(otherData!)
    }

    public var fullMessageDataLength: Int {
        otherDataLength + 1
    }

    // Manufacturer ID bytes. May be 1 to 3 bytes in length, or nil if it can't be determined.
    public var manufacturerIdentifier: Data? {
        guard data.count > 0 else { return nil }

        // If the first byte is not 0, the manufacturer ID is one byte long. Otherwise, return a three-byte value (if possible).
        if data.first! != 0 {
            return data.subdata(in: data.startIndex ..< data.startIndex+1)
        }
        else if data.count >= 3 {
            return data.subdata(in: data.startIndex ..< data.startIndex+3)
        }
        else {
            return nil
        }
    }

    public var manufacturerName: String? {
        guard let identifier = manufacturerIdentifier else { return nil }
        return MessageFormatter.nameForManufacturerIdentifier(identifier)
    }

    public var sizeForDisplay: String {
        let formattedLength = MessageFormatter.formatLength(receivedDataWithStartByteLength)
        let format = NSLocalizedString("%@ bytes", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "SysEx length format string")
        return String.localizedStringWithFormat(format, formattedLength)
    }

    // MARK: Private

    private var cachedDataWithEOX: Data?

    private func dataByAddingStartByte(_ someData: Data) -> Data {
        var result = someData
        result.insert(0xF0, at: result.startIndex)
        return result
    }

    // MARK: Message overrides

    public override var messageType: TypeMask {
        .systemExclusive
    }

    public override var typeForDisplay: String {
        NSLocalizedString("SysEx", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of System Exclusive event")
    }

    public override var dataForDisplay: String {
        var result = ""
        if let name = manufacturerName {
            result += name + " "
        }
        result += sizeForDisplay
        result += "\t"
        result += expertDataForDisplay
        return result
    }

    public override var expertDataForDisplay: String {
        return MessageFormatter.formatExpertStatusByte(statusByte, otherData: receivedData)
    }

}

extension SystemExclusiveMessage {

    // Convert an array of sysex messages to a single chunk of data (e.g. for a .syx file),
    // and vice-versa.

    public static func messages(fromData data: Data) -> [SystemExclusiveMessage] {
        // Scan through data and make messages out of it.
        // Messages must start with 0xF0.  Messages may end in any byte >= 0x80.

        var messages: [SystemExclusiveMessage] = []

        var inMessage = false
        var messageDataBounds = (lower: data.startIndex, upper: data.startIndex)

        func addMessageIfPossible() {
            let range = messageDataBounds.lower ..< messageDataBounds.upper
            if !range.isEmpty {
                let sysexData = data.subdata(in: range)
                let message = SystemExclusiveMessage(timeStamp: 0, data: sysexData)
                messages.append(message)
            }
        }

        for (index, byte) in data.enumerated() {
            if inMessage && byte >= 0x80 {
                // end of the current message
                messageDataBounds.upper = index
                addMessageIfPossible()
                inMessage = false
            }

            if byte == 0xF0 {
                // start of the next message
                inMessage = true
                messageDataBounds.lower = index + 1
            }
        }

        if inMessage {
            messageDataBounds.upper = data.endIndex
            addMessageIfPossible()
        }

        return messages
    }

    public static func data(forMessages messages: [SystemExclusiveMessage]) -> Data? {
        guard messages.count > 0 else { return nil }

        var resultData = Data()

        // Reserve capacity for all the data up front, before concatenating.
        // Each message is represented as 0xF0 + message.data + 0xF7
        var totalCount: Int = 0
        for message in messages {
            totalCount += 1 + message.data.count + 1
        }
        resultData.reserveCapacity(totalCount)

        for message in messages {
            resultData.append(0xF0)
            resultData.append(message.data)
            resultData.append(0xF7)
        }

        return resultData
    }

}

import AudioToolbox

extension SystemExclusiveMessage {

    // Extract sysex messages from a Standard MIDI file, and vice-versa.

    public static func messages(fromStandardMIDIFileData data: Data) -> [SystemExclusiveMessage] {
        var possibleSequence: MusicSequence?
        guard NewMusicSequence(&possibleSequence) == noErr, let sequence = possibleSequence else { return [] }
        defer { _ = DisposeMusicSequence(sequence) }

        guard MusicSequenceFileLoadData(sequence, data as CFData, .midiType, .smf_ChannelsToTracks) == noErr else { return [] }

        // The last track should contain any sysex data.
        var trackCount: UInt32 = 0
        if MusicSequenceGetTrackCount(sequence, &trackCount) == noErr {
            var possibleTrack: MusicTrack?
            if MusicSequenceGetIndTrack(sequence, trackCount - 1, &possibleTrack) == noErr,
               let track = possibleTrack {
                return messages(fromTrack: track)
            }
        }

        return []
    }

    static private func messages(fromTrack track: MusicTrack) -> [SystemExclusiveMessage] {
        // Iterate through the events, looking for MIDI "raw data" events, which may contain sysex data.
        // (The names get confusing, because we also use Swift's "raw pointers" to get to the data
        // from this old C-based API.)

        var messages: [SystemExclusiveMessage] = []

        var possibleIterator: MusicEventIterator?
        if NewMusicEventIterator(track, &possibleIterator) == noErr,
           let iterator = possibleIterator {
            defer { _ = DisposeMusicEventIterator(iterator) }

            var accumulatingSysexData: Data?

            var hasCurrentEvent: DarwinBoolean = false
            MusicEventIteratorHasCurrentEvent(iterator, &hasCurrentEvent)
            while hasCurrentEvent.boolValue {
                var timeStamp: MusicTimeStamp = 0   // ignored
                var eventType: MusicEventType = kMusicEventType_NULL
                var eventData: UnsafeRawPointer?
                var eventDataSize: UInt32 = 0

                let status = MusicEventIteratorGetEventInfo(iterator, &timeStamp, &eventType, &eventData, &eventDataSize)

                if status == noErr && eventType == kMusicEventType_MIDIRawData && eventDataSize > 0,
                   let eventData {
                    // eventData is a pointer to a MIDIRawData struct, which contains
                    // another length field and then the "raw" MIDI data.
                    let midiRawDataEventPtr = eventData.bindMemory(to: MIDIRawData.self, capacity: Int(eventDataSize))
                    let midiRawDataLength = Int(midiRawDataEventPtr.pointee.length)
                    if midiRawDataLength > 0 {
                        // You might try to do this:
                        // withUnsafePointer(to: midiRawDataEventPtr.pointee.data) { midiRawDataPtr in
                        //     let midiRawData = Data(UnsafeBufferPointer(start: midiRawDataPtr, count: midiRawDataLength))
                        // but ASAN dislikes that, so construct the pointer to the data manually.
                        let midiRawData = Data(bytes: eventData + MemoryLayout.offset(of: \MIDIRawData.data)!, count: midiRawDataLength)

                        let firstByte = midiRawData.first!
                        if firstByte == 0xF0 {
                            // Starting a sysex message. Omit the 0xF0.
                            accumulatingSysexData = midiRawData.dropFirst()
                        }
                        else if accumulatingSysexData != nil {
                            // Continuing a sysex message.
                            // (This can happen in theory according to the SMF spec, but I'm not seeing it in practice;
                            //  it's possible that MusicSequence abstracts this away by concatenating sysex events together
                            //  before we see them. If this does happen, I'm not sure whether we will see the event data
                            //  starting with 0xF7 or not, so handle both ways.)
                            if firstByte == 0xF7 {
                                accumulatingSysexData?.append(midiRawData.dropFirst())
                            }
                            else {
                                accumulatingSysexData?.append(midiRawData)
                            }
                        }

                        if let accumulatedSysexData = accumulatingSysexData,
                           accumulatedSysexData.count > 1,
                           accumulatedSysexData.last! == 0xF7 {
                            // Ending a sysex message.
                            // Cut off the ending 0xF7 byte and create a message.
                            let sysexMessage = SystemExclusiveMessage(timeStamp: 0, data: accumulatedSysexData.dropLast())
                            messages.append(sysexMessage)

                            accumulatingSysexData = nil
                        }
                    }
                }

                _ = MusicEventIteratorNextEvent(iterator)
                _ = MusicEventIteratorHasCurrentEvent(iterator, &hasCurrentEvent)
            }
        }

        return messages
    }

    public static func standardMIDIFileData(forMessages messages: [SystemExclusiveMessage]) -> Data? {
        guard messages.count > 0 else { return nil }

        var possibleSequence: MusicSequence?
        guard NewMusicSequence(&possibleSequence) == noErr, let sequence = possibleSequence else { return nil }
        defer { _ = DisposeMusicSequence(sequence) }

        var possibleTrack: MusicTrack?
        guard MusicSequenceNewTrack(sequence, &possibleTrack) == noErr, let track = possibleTrack else { return nil }

        var timeStamp: MusicTimeStamp = 0
        for message in messages {
            let messageData = message.fullMessageData

            // Create a buffer large enough for a MIDIRawData struct containing all messageData
            let structCount = MemoryLayout.offset(of: \MIDIRawData.data)! + messageData.count
            let mutableRawPointer = UnsafeMutableRawPointer.allocate(byteCount: structCount, alignment: MemoryLayout<MIDIRawData>.alignment)
            defer { mutableRawPointer.deallocate() }

            let midiRawDataPtr = mutableRawPointer.bindMemory(to: MIDIRawData.self, capacity: structCount)
            midiRawDataPtr.pointee.length = UInt32(messageData.count)
            messageData.copyBytes(to: &midiRawDataPtr.pointee.data, count: messageData.count)

            guard MusicTrackNewMIDIRawDataEvent(track, timeStamp, midiRawDataPtr) == noErr else { return nil }

            // Advance timeStamp by the duration required to send this message,
            // plus a gap between messages
            let midiSpeed = 3125.0  // bytes / sec
            let midiDuration = Double(messageData.count) / midiSpeed
            let gapDuration = 0.150 // seconds
            var durationTimeStamp: MusicTimeStamp = 0
            MusicSequenceGetBeatsForSeconds(sequence, Float64(midiDuration + gapDuration), &durationTimeStamp)
            timeStamp += durationTimeStamp
        }

        var unmanagedResultData: Unmanaged<CFData>?
        guard MusicSequenceFileCreateData(sequence, .midiType, MusicSequenceFileFlags(rawValue: 0), 0, &unmanagedResultData) == noErr else { return nil }
        return unmanagedResultData?.takeRetainedValue() as Data?
    }

}

public class HackSystemExclusiveMessage: SystemExclusiveMessage {

    // Data without the starting 0xF0, and hacked to not include ending 0xF7.
    public override var otherData: Data? {
        guard let withF7 = super.otherData else { return nil }
        let len = withF7.count
        if len == 0 {
            return withF7
        }
        else {
            return withF7.subdata(in: 0..<(len - 1))
        }
    }

}
