/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

protocol MessageParserDelegate: AnyObject {

    func parserDidReadMessages(_ parser: MessageParser, messages: [Message])
    func parserIsReadingSysEx(_ parser: MessageParser, length: Int)
    func parserFinishedReadingSysEx(_ parser: MessageParser, message: SystemExclusiveMessage)

}

public class MessageParser {

    deinit {
        sysExTimeOutTimer?.invalidate()
    }

    weak var delegate: MessageParserDelegate?
    public weak var originatingEndpoint: Endpoint?
    public var sysExTimeOut: TimeInterval = 1.0   // seconds
    public var ignoresInvalidData = false

    public func takePacketList(_ packetListPtr: UnsafePointer<MIDIPacketList>) {
        var messages: [Message] = []

        if #available(macOS 10.15, iOS 13.0, *) {
            messages = packetListPtr.unsafeSequence().flatMap { messagesForPacket($0) }
        }
        else {
            // Fallback on earlier versions
            SMPacketListApply(packetListPtr) {
                messages.append(contentsOf: messagesForPacket($0))
            }
        }

        if !messages.isEmpty {
            delegate?.parserDidReadMessages(self, messages: messages)
        }

        if readingSysExData != nil {
            if sysExTimeOutTimer == nil {
                // Create a timer which will fire after we have received no sysex data for a while.
                // This takes care of interruption in the data (devices being turned off or unplugged) as well as
                // ill-behaved devices which don't terminate their sysex messages with 0xF7.
                sysExTimeOutTimer = Timer.scheduledTimer(timeInterval: sysExTimeOut, target: self, selector: #selector(sysExTimedOut(_:)), userInfo: nil, repeats: false)
            }
            else {
                // We already have a timer, so just bump its fire date to later.
                sysExTimeOutTimer?.fireDate = Date(timeIntervalSinceNow: sysExTimeOut)
            }
        }
        else {
            // Not reading sysex, so if we have a timeout pending, forget about it
            sysExTimeOutTimer?.invalidate()
            sysExTimeOutTimer = nil
        }
    }

    @discardableResult public func cancelReceivingSysExMessage() -> Bool {
        // Returns YES if it successfully cancels a sysex message which is being received, and NO otherwise.
        if readingSysExData != nil {
            readingSysExData = nil
            return true
        }
        else {
            return false
        }
    }

    // MARK: Private

    private var readingSysExData: Data?
    private var startSysExTimeStamp: MIDITimeStamp = 0
    private var sysExTimeOutTimer: Timer?

    private struct PendingMessage {
        var status: UInt8 = 0
        var data: [UInt8] = []
        var expectedCount: Int = 0
    }

    private func messagesForPacket(_ packetPtr: UnsafePointer<MIDIPacket>) -> [Message] {
        // Split this packet into separate MIDI messages.

        let packetDataCount = Int(packetPtr.pointee.length)
        guard packetDataCount > 0 else { return [] }
        let timeStamp = packetPtr.pointee.timeStamp

        var pendingMessage = PendingMessage()
        var readingInvalidData: Data?

        // Safely getting to the packet data is more difficult than it should be.
        // Can't use withUnsafePointer(to: packetPtr.pointee.data.0) since that crashes with ASAN on.
        // (Accessing `pointee` appears to be trying to copy 256 bytes of data, which may be more than
        // is really accessible.)
        // Can't use withUnsafeBytes(of: packetPtr.pointee.data) since that limits to the 256 bytes
        // in the tuple in the struct. There may be more.
        // Do it the hard way instead.
        let rawPacketDataPtr = UnsafeRawBufferPointer(start: UnsafeRawPointer(packetPtr) + MemoryLayout.offset(of: \MIDIPacket.data)!, count: packetDataCount)
        return rawPacketDataPtr.enumerated().flatMap { (byteIndex, byte) -> [Message] in
            var messages: [Message] = []
            var byteIsInvalid = false

            var maybeMessage: Message?
            if byte >= 0xF8 {
                // Real Time message, always one byte, may be interspersed anywhere in other messages (including SysEx)
                (maybeMessage, byteIsInvalid) = parseRealTimeMessage(byte, timeStamp)
            }
            else if byte < 0x80 {
                // Message data byte, goes into pendingMessage, might complete a multibyte message
                (maybeMessage, byteIsInvalid) = parseMessageData(byte, timeStamp, &pendingMessage)
            }
            else if byte == 0xF7 {
                // Explicit end of a SysEx message
                if let sysExMessage = finishSysExMessage(validEnd: true) {
                    messages.append(sysExMessage)
                }
                else {
                    // SysEx end byte with no SysEx message being read. Technically invalid.
                    byteIsInvalid = true
                }
            }
            else {
                // Start of a non-real-time message.
                // This terminates the current SysEx message, if any
                if let sysExMessage = finishSysExMessage(validEnd: false) {
                    messages.append(sysExMessage)
                }
                (maybeMessage, byteIsInvalid) = parseMessageStart(byte, timeStamp, &pendingMessage)
            }

            if let message = maybeMessage {
                messages.append(message)
            }

            if !ignoresInvalidData,
               let invalidMessage = parsePotentiallyInvalidByte(byte, timeStamp, byteIsInvalid, (byteIndex == packetDataCount - 1), &readingInvalidData) {
                messages.append(invalidMessage)
            }

            messages.forEach { $0.originatingEndpoint = originatingEndpoint }
            return messages
        }
    }

    private func parseRealTimeMessage(_ byte: UInt8, _ timeStamp: MIDITimeStamp) -> (Message?, Bool) {
        // Real Time message
        if let messageType = SystemRealTimeMessage.MessageType(rawValue: byte) {
            return (SystemRealTimeMessage(timeStamp: timeStamp, type: messageType), false)
        }
        else {
            return (nil, true)
        }
    }

    private func parseMessageData(_ byte: UInt8, _ timeStamp: MIDITimeStamp, _ pendingMessage: inout PendingMessage) -> (Message?, Bool) {
        // N.B. Be careful about performance here. Doing something like this will be slow,
        //      probably N^2 with the number of sysex bytes read:
        //
        //     if let data = readingSysExData {
        //         readingSysExData?.append(byte)
        //         ...
        //
        // `readingSysExData` is a `Data` which is a value object, and thus `if let` or `if var` always copy
        // that value object. (See: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0345-if-let-shorthand.md
        // which says "optional binding conditions always make a copy of the value"; the hoped-for fix in
        // https://forums.swift.org/t/a-roadmap-for-improving-swift-performance-predictability-arc-improvements-and-ownership-control/54206/268
        // has not yet landed.)
        //
        // The perf problem appears when we append the byte, because that's when COW actually needs to copy the original bytes.

        if readingSysExData != nil {
            readingSysExData!.append(byte)

            // Tell the delegate we're still reading, every 256 bytes
            let sysExMessageDataCount = 1 /* for 0xF0 */ + readingSysExData!.count
            if sysExMessageDataCount % 256 == 0 {
                delegate?.parserIsReadingSysEx(self, length: sysExMessageDataCount)
            }
        }
        else if pendingMessage.data.count < pendingMessage.expectedCount {
            pendingMessage.data.append(byte)

            if pendingMessage.data.count == pendingMessage.expectedCount {
                // This message is now done
                if let status = SystemCommonMessage.Status(rawValue: pendingMessage.status) {
                    return (SystemCommonMessage(timeStamp: timeStamp, status: status, data: pendingMessage.data), false)
                }
                else {
                    return (VoiceMessage(timeStamp: timeStamp, statusByte: pendingMessage.status, data: pendingMessage.data), false)
                }
            }
        }
        else {
            // Skip this byte -- it is invalid
            return (nil, true)
        }

        // No message yet, but this byte was valid
        return (nil, false)
    }

    private func parseMessageStart(_ byte: UInt8, _ timeStamp: MIDITimeStamp, _ pendingMessage: inout PendingMessage) -> (Message?, Bool) {
        var message: Message?
        var byteIsInvalid = false

        pendingMessage.status = byte
        pendingMessage.data = []
        pendingMessage.expectedCount = 0

        switch byte & 0xF0 {
        case 0x80,    // Note off
             0x90,    // Note on
             0xA0,    // Aftertouch
             0xB0,    // Controller
             0xE0:    // Pitch wheel
            pendingMessage.expectedCount = 2

        case 0xC0,    // Program change
             0xD0:    // Channel pressure
            pendingMessage.expectedCount = 1

        case 0xF0:
            // System common message
            if byte == 0xF0 {
                // System exclusive start
                readingSysExData = Data()
                startSysExTimeStamp = timeStamp
                delegate?.parserIsReadingSysEx(self, length: 1)
            }
            else if let systemCommonMessageStatus = SystemCommonMessage.Status(rawValue: byte) {
                let dataLength = systemCommonMessageStatus.otherDataLength
                if dataLength > 0 {
                    pendingMessage.expectedCount = dataLength
                }
                else {
                    message = SystemCommonMessage(timeStamp: timeStamp, status: systemCommonMessageStatus, data: [])
                }
            }
            else {
                // Invalid message
                byteIsInvalid = true
            }

        default:
            // This can't happen, but handle it anyway
            byteIsInvalid = true
        }

        return (message, byteIsInvalid)
    }

    private func finishSysExMessage(validEnd: Bool) -> SystemExclusiveMessage? {
        // NOTE: If we want, we could refuse sysex messages that don't end in 0xF7.
        // The MIDI spec says that messages should end with this byte, but apparently that is not always the case in practice.
        guard let data = readingSysExData else { return nil }
        readingSysExData = nil

        let message = SystemExclusiveMessage(timeStamp: startSysExTimeStamp, data: data)
        message.originatingEndpoint = originatingEndpoint
        message.wasReceivedWithEOX = validEnd
        delegate?.parserFinishedReadingSysEx(self, message: message)

        return message
    }

    private func parsePotentiallyInvalidByte(_ byte: UInt8, _ timeStamp: MIDITimeStamp, _ byteIsInvalid: Bool, _ isLastByteInPacket: Bool, _ readingInvalidData: inout Data?) -> Message? {
        if byteIsInvalid {
            if readingInvalidData == nil {
                readingInvalidData = Data()
            }
            readingInvalidData?.append(byte)
        }

        if let invalidData = readingInvalidData,
           !byteIsInvalid || isLastByteInPacket {
            // We hit the end of a stretch of invalid data.
            readingInvalidData = nil
            return InvalidMessage(timeStamp: timeStamp, data: invalidData)
        }
        else {
            return nil
        }
    }

    @objc private func sysExTimedOut(_ timer: Timer) {
        sysExTimeOutTimer = nil
        if let message = finishSysExMessage(validEnd: false) {
            delegate?.parserDidReadMessages(self, messages: [message])
        }
    }

}
