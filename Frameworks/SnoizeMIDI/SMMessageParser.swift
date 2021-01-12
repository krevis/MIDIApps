/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

// TODO This probably doesn't need to be objc or public.
@objc public protocol SMMessageParserDelegate {

    func parserDidReadMessages(_ parser: SMMessageParser, messages: [SMMessage])
    func parserIsReadingSysEx(_ parser: SMMessageParser, length: Int)
    func parserFinishedReadingSysEx(_ parser: SMMessageParser, message: SMSystemExclusiveMessage)

}

@objc public class SMMessageParser: NSObject {

    @objc override init() {
        super.init()
    }

    deinit {
        sysExTimeOutTimer?.invalidate()
    }

    @objc public weak var delegate: SMMessageParserDelegate?
    @objc public weak var originatingEndpoint: SMEndpoint?
    @objc public var sysExTimeOut: TimeInterval = 1.0   // seconds
    @objc public var ignoresInvalidData = false

    @objc public func takePacketList(_ packetListPtr: UnsafePointer<MIDIPacketList>) {
        var messages: [SMMessage] = []

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
    private func messagesForPacket(_ packetPtr: UnsafePointer<MIDIPacket>) -> [SMMessage] {
        // Split this packet into separate MIDI messages.

        let packetDataCount = packetPtr.pointee.length
        let timeStamp = packetPtr.pointee.timeStamp

        var pendingMessageStatus: UInt8 = 0
        var pendingDataBytes: [UInt8] = [0, 0]
        var pendingDataIndex = 0
        var pendingDataLength = 0

        var readingInvalidData: Data?

        // Can't use withUnsafeBytes(of: packetPtr.pointee.data) since that limits to the 256 bytes
        // in the tuple in the struct.  Do it the hard way instead.
        let rawPacketDataPtr = UnsafeRawBufferPointer(start: UnsafeRawPointer(packetPtr) + MemoryLayout.offset(of: \MIDIPacket.data)!, count: Int(packetDataCount))
        let bufferPtr = rawPacketDataPtr.bindMemory(to: UInt8.self)

        let messages = bufferPtr.enumerated().compactMap { (byteIndex, byte) -> SMMessage? in
            var message: SMMessage?
            var byteIsInvalid = false

            if byte >= 0xF8 {
                // Real Time message
                if let messageType = SMSystemRealTimeMessage.MessageType(rawValue: byte) {
                    message = SMSystemRealTimeMessage(timeStamp: timeStamp, type: messageType)
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
                            message = SMSystemCommonMessage(timeStamp: timeStamp, type: SMSystemCommonMessage.MessageType(rawValue: pendingMessageStatus)!, data: Array(pendingDataBytes.prefix(upTo: pendingDataLength)))
                        }
                        else {
                            message = SMVoiceMessage(timeStamp: timeStamp, statusByte: pendingMessageStatus, data: pendingDataBytes, length: UInt16(pendingDataLength))
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
                    switch byte {
                    case 0xF0:
                        // System exclusive
                        readingSysExData = Data()
                        startSysExTimeStamp = timeStamp
                        delegate?.parserIsReadingSysEx(self, length: 1)

                    case 0xF7:
                        // System exclusive ends--already handled above.
                        // But if this is showing up outside of sysex, it's invalid.
                        if message == nil {
                            byteIsInvalid = true
                        }

                    case SMSystemCommonMessage.MessageType.timeCodeQuarterFrame.rawValue,
                         SMSystemCommonMessage.MessageType.songSelect.rawValue:
                        pendingDataLength = 1

                    case SMSystemCommonMessage.MessageType.songPositionPointer.rawValue:
                        pendingDataLength = 2

                    case SMSystemCommonMessage.MessageType.tuneRequest.rawValue:
                        message = SMSystemCommonMessage(timeStamp: timeStamp, type: SMSystemCommonMessage.MessageType(rawValue: byte)!, data: [])

                    default:
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
                    message = SMInvalidMessage(timeStamp: timeStamp, data: invalidData)
                    readingInvalidData = nil
                }
            }

            message?.originatingEndpoint = originatingEndpoint
            return message
        }

        return messages
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    private func finishSysExMessage(validEnd: Bool) -> SMSystemExclusiveMessage? {
        // NOTE: If we want, we could refuse sysex messages that don't end in 0xF7.
        // The MIDI spec says that messages should end with this byte, but apparently that is not always the case in practice.
        guard let data = readingSysExData else { return nil }
        readingSysExData = nil

        let sysExMessage = SMSystemExclusiveMessage(timeStamp: startSysExTimeStamp, data: data)
        // TODO initializer shouldn't be optional
        if let message = sysExMessage {
            message.originatingEndpoint = originatingEndpoint
            message.wasReceivedWithEOX = validEnd
            delegate?.parserFinishedReadingSysEx(self, message: message)
        }

        return sysExMessage
    }

    @objc private func sysExTimedOut(_ timer: Timer) {
        sysExTimeOutTimer = nil
        if let message = finishSysExMessage(validEnd: false) {
            delegate?.parserDidReadMessages(self, messages: [message])
        }
    }

}
