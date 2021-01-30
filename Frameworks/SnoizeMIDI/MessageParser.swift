/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

protocol MessageParserDelegate: AnyObject {

    func parserDidReadMessages(_ parser: MessageParser, messages: [Message])
    func parserIsReadingSysEx(_ parser: MessageParser, length: Int)
    func parserFinishedReadingSysEx(_ parser: MessageParser, message: SystemExclusiveMessage)

}

@objc public class MessageParser: NSObject {

    deinit {
        sysExTimeOutTimer?.invalidate()
    }

    weak var delegate: MessageParserDelegate?
    public weak var originatingEndpoint: Endpoint?
    @objc public var sysExTimeOut: TimeInterval = 1.0   // seconds
    @objc public var ignoresInvalidData = false

    @objc public func takePacketList(_ packetListPtr: UnsafePointer<MIDIPacketList>) {
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

    @objc public func cancelReceivingSysExMessage() -> Bool {
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

    // swiftlint:disable cyclomatic_complexity function_body_length
    // (Sorry! TODO: Fix overly long and complex function)
    private func messagesForPacket(_ packetPtr: UnsafePointer<MIDIPacket>) -> [Message] {
        // Split this packet into separate MIDI messages.

        let packetDataCount = Int(packetPtr.pointee.length)
        guard packetDataCount > 0 else { return [] }
        let timeStamp = packetPtr.pointee.timeStamp

        var pendingMessageStatus: UInt8 = 0
        var pendingDataBytes: [UInt8] = [0, 0]
        var pendingDataIndex = 0
        var pendingDataLength = 0

        var readingInvalidData: Data?

        // Safely getting to the packet data is more difficult than it should be.
        // Can't use withUnsafePointer(to: packetPtr.pointee.data.0) since that crashes with ASAN on.
        // (Accessing `pointee` appears to be trying to copy 256 bytes of data, which may be more than
        // is really accessible.)
        // Can't use withUnsafeBytes(of: packetPtr.pointee.data) since that limits to the 256 bytes
        // in the tuple in the struct. There may be more.
        // Do it the hard way instead.
        let rawPacketDataPtr = UnsafeRawBufferPointer(start: UnsafeRawPointer(packetPtr) + MemoryLayout.offset(of: \MIDIPacket.data)!, count: packetDataCount)
        return rawPacketDataPtr.enumerated().compactMap { (byteIndex, byte) -> Message? in
            var message: Message?
            var byteIsInvalid = false

            if byte >= 0xF8 {
                // Real Time message
                if let messageType = SystemRealTimeMessage.MessageType(rawValue: byte) {
                    message = SystemRealTimeMessage(timeStamp: timeStamp, type: messageType)
                }
                else {
                    // Byte is invalid
                    byteIsInvalid = true
                }
            }
            else if byte < 0x80 {
                if let data = readingSysExData {
                    readingSysExData?.append(byte)

                    // Tell the delegate we're still reading, every 256 bytes
                    let sysExMessageDataCount = 1 /* for 0xF0 */ + data.count
                    if sysExMessageDataCount % 256 == 0 {
                        delegate?.parserIsReadingSysEx(self, length: sysExMessageDataCount)
                    }
                }
                else if pendingDataIndex < pendingDataLength {
                    pendingDataBytes[pendingDataIndex] = byte
                    pendingDataIndex += 1

                    if pendingDataIndex == pendingDataLength {
                        // This message is now done
                        if pendingMessageStatus >= 0xF0 {
                            message = SystemCommonMessage(timeStamp: timeStamp, type: SystemCommonMessage.CommonMessageType(rawValue: pendingMessageStatus)!, data: Array(pendingDataBytes.prefix(upTo: pendingDataLength)))
                        }
                        else {
                            message = VoiceMessage(timeStamp: timeStamp, statusByte: pendingMessageStatus, data: pendingDataBytes)
                        }
                    }
                }
                else {
                    // Skip this byte -- it is invalid
                    byteIsInvalid = true
                }
            }
            else {
                if readingSysExData != nil {
                    message = finishSysExMessage(validEnd: (byte == 0xF7))
                }

                pendingMessageStatus = byte
                pendingDataLength = 0
                pendingDataIndex = 0

                switch byte & 0xF0 {
                case 0x80,    // Note off
                     0x90,    // Note on
                     0xA0,    // Aftertouch
                     0xB0,    // Controller
                     0xE0:    // Pitch wheel
                    pendingDataLength = 2

                case 0xC0,    // Program change
                     0xD0:    // Channel pressure
                    pendingDataLength = 1

                case 0xF0:
                    // System common message
                    if byte == 0xF0 {
                        // System exclusive
                        readingSysExData = Data()
                        startSysExTimeStamp = timeStamp
                        delegate?.parserIsReadingSysEx(self, length: 1)
                    }
                    else if byte == 0xF7 {
                        // System exclusive ends--already handled above.
                        // But if this is showing up outside of sysex, it's invalid.
                        if message == nil {
                            byteIsInvalid = true
                        }
                    }
                    else if let systemCommonMessageType = SystemCommonMessage.CommonMessageType(rawValue: byte) {
                        let dataLength = systemCommonMessageType.otherDataLength
                        if dataLength > 0 {
                            pendingDataLength = dataLength
                        }
                        else {
                            message = SystemCommonMessage(timeStamp: timeStamp, type: systemCommonMessageType, data: [])
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
            }

            if !ignoresInvalidData {
                if byteIsInvalid {
                    if readingInvalidData == nil {
                        readingInvalidData = Data()
                    }
                    readingInvalidData?.append(byte)
                }

                if let invalidData = readingInvalidData,
                   !byteIsInvalid || byteIndex == packetDataCount - 1 {
                    // We hit the end of a stretch of invalid data.
                    message = InvalidMessage(timeStamp: timeStamp, data: invalidData)
                    readingInvalidData = nil
                }
            }

            message?.originatingEndpoint = originatingEndpoint
            return message
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

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

    @objc private func sysExTimedOut(_ timer: Timer) {
        sysExTimeOutTimer = nil
        if let message = finishSysExMessage(validEnd: false) {
            delegate?.parserDidReadMessages(self, messages: [message])
        }
    }

}
