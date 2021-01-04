/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CoreAudio

@objc public class SMOutputStream: NSObject {

    @objc public var ignoresTimeStamps = false

    // MARK: Framework internal

    internal func send(_ packetListPtr: UnsafePointer<MIDIPacketList>) {
        // Must be overridden by subclasses
        fatalError()
    }

    // MARK: Internal

    // CoreMIDI's MIDIPacketList struct is variable-size, consisting of a small
    // header followed by one or more variable-size MIDIPacket structs.
    // The types limit MIDIPacket to holding at most 2^16 - 1 = 65535 bytes,
    // and the MIDIPacketList to holding 2^32 - 1 packets.
    //
    // It's plausible that a large sysex message could exceed the max packet size,
    // but we should be able to split it across multiple packets. The packet
    // count is (almost) unlimited, so we should be able to use a single packet list.
    //
    // BUT, it's not clear we can actually rely on that.
    // `MIDIPacketListAdd` has this comment:
    // > The maximum size of a packet list is 65536 bytes.
    // > Large sysex messages must be sent in smaller packet lists.
    // That seems dumb, and maybe they just meant "packet" instead of "packet list",
    // but why risk it? Just send as many packet lists as are needed.
    //
    // (Back in Mac OS X 10.1, the MIDIServer would crash if you exceeded
    // 1024 bytes in a packet list. So it's not inconceivable that the implementation
    // could have similar limits even today.)
    //
    // Switch to newer CoreMIDI API (introduced in 10.15 or 11.0) when we can.

    private let maxPacketSize = 65536
    private let maxPacketListSize = 65536
    private let midiPacketListHeaderSize = MemoryLayout.offset(of: \MIDIPacketList.packet)!
    private let midiPacketHeaderSize = MemoryLayout.offset(of: \MIDIPacket.data)!

    private func sendMessagesWithLimitedPacketListSize(_ messages: [SMMessage]) {
        guard messages.count > 0 else { return }

        let rawPacketListPtr = UnsafeMutableRawPointer.allocate(byteCount: maxPacketListSize, alignment: MemoryLayout<MIDIPacketList>.alignment)
        let packetListPtr = rawPacketListPtr.initializeMemory(as: MIDIPacketList.self, repeating: MIDIPacketList(), count: 1)

        var packetPtr = MIDIPacketListInit(packetListPtr)
        var packetListSize = midiPacketListHeaderSize

        func addPacket(_ curPacketPtr: inout UnsafeMutablePointer<MIDIPacket>, _ message: SMMessage, _ data: Data) {
            // Add a packet to the packet list, for the given message,
            // with this data (either the message's fullData or a subrange).
            curPacketPtr.pointee.timeStamp = ignoresTimeStamps ? AudioGetCurrentHostTime() : message.timeStamp
            curPacketPtr.pointee.length = UInt16(data.count)

            let rawPacketPtr = UnsafeMutableRawPointer(curPacketPtr)
            let rawPacketBufferPtr = UnsafeMutableRawBufferPointer(start: rawPacketPtr + midiPacketHeaderSize, count: maxPacketSize)
            rawPacketBufferPtr.copyBytes(from: data)

            packetListPtr.pointee.numPackets += 1
            curPacketPtr = MIDIPacketNext(curPacketPtr)
            // MIDIPacketNext() may have added padding for alignment (especially on ARM),
            // so the packetListSize may increase by more than midiPacketHeaderSize + data.count
            packetListSize += UnsafeMutableRawPointer(curPacketPtr) - rawPacketPtr
        }

        func sendPacketList(_ curPacketPtr: inout UnsafeMutablePointer<MIDIPacket>) {
            send(packetListPtr)
            // and reset the packet list
            curPacketPtr = MIDIPacketListInit(packetListPtr)
            packetListSize = midiPacketListHeaderSize
        }

        for message in messages {
            // Get the full data for the message (including first status byte)
            guard let messageFullData = message.fullData, messageFullData.count > 0 else { continue }
            // There is some overhead for each packet
            let desiredPacketSize = midiPacketHeaderSize + messageFullData.count

            // If this packet list already contains packets, is there room in it
            // for this whole message?
            if packetListPtr.pointee.numPackets > 0 && packetListSize + desiredPacketSize > maxPacketListSize {
                // No, there is not enough room. Send the current packet list
                // to get it out of the way.
                // Send the current packet list, and reset it so it's empty again.
                sendPacketList(&packetPtr)
            }

            if packetListSize + desiredPacketSize <= maxPacketListSize {
                // There is room for the whole message. Add it in a packet.
                addPacket(&packetPtr, message, message.fullData)
            }
            else {
                // This is a large sysex message. We send it by filling in
                // the packet list with one packet with as much data as possible,
                // sending that packet list, then repeating with the rmaining data.
                // We can send this much data at a time:
                let maxPacketDataSize = maxPacketListSize - midiPacketListHeaderSize - midiPacketHeaderSize

                var dataSizeRemaining = messageFullData.count
                while dataSizeRemaining > 0 {
                    let partialDataSize = min(dataSizeRemaining, maxPacketDataSize)
                    let dataRangeStartIndex = messageFullData.count - dataSizeRemaining
                    dataSizeRemaining -= partialDataSize

                    let messageSubData = messageFullData.subdata(in: dataRangeStartIndex ..< (dataRangeStartIndex + partialDataSize))
                    addPacket(&packetPtr, message, messageSubData)
                    sendPacketList(&packetPtr)
                }
            }
        }

        // All messages have been processed. Send the last remaining packet list.
        if packetListPtr.pointee.numPackets > 0 {
            send(packetListPtr)
        }

        rawPacketListPtr.deallocate()
    }

}

@objc extension SMOutputStream: SMMessageDestination {

    public func takeMIDIMessages(_ messages: [SMMessage]!) {
        sendMessagesWithLimitedPacketListSize(messages)
    }

}
