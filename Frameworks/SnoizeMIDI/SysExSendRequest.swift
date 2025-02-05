/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class SysExSendRequest: NSObject {

    init?(message: SystemExclusiveMessage, destination: Destination, customSysExBufferSize: Int = 0) {
        self.midiContext = destination.midiContext
        self.message = message
        self.customSysExBufferSize = customSysExBufferSize

        let fullMessageData = message.fullData
        // MIDISysexSendRequest length is "only" a UInt32
        guard fullMessageData.count < UInt32.max else { return nil }

        // Swift.Data doesn't provide a way to get a long-lived pointer
        // into its bytes. We need to copy the data to a separate buffer,
        // then make the MIDISysexSendRequest take bytes from there.
        dataCount = fullMessageData.count
        let mutableBufferPtr = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: dataCount)
        _ = mutableBufferPtr.initialize(from: fullMessageData)
        dataPointer = UnsafePointer(mutableBufferPtr.baseAddress!)

        maxSysExSpeed = Int(destination.maxSysExSpeed)

        sysexSendRequest = MIDISysexSendRequest(
            destination: destination.endpointRef,
            data: dataPointer,
            bytesToSend: UInt32(dataCount),
            complete: false,
            reserved: (0, 0, 0),
            completionProc: { (unsafeRequest: UnsafeMutablePointer<MIDISysexSendRequest>) in
                // NOTE: This is called on CoreMIDI's sysex sending thread.
                guard let refCon = unsafeRequest.pointee.completionRefCon else { return }
                let request = Unmanaged<SysExSendRequest>.fromOpaque(refCon).takeRetainedValue()
                DispatchQueue.main.async {
                    request.didComplete(.sent)
                }
            },
            completionRefCon: nil)

        super.init()
    }

    deinit {
        dataPointer.deallocate()
    }

    public weak var delegate: SysExSendRequestDelegate?

    public let message: SystemExclusiveMessage
    public let customSysExBufferSize: Int

    @discardableResult public func send() -> Bool {
        checkMainQueue()

        guard state == .pending else { return false }

        // Put a retained reference to self in the refCon in the MIDISysexSendRequest.
        // This must be balanced later, when the completion closure is called.
        let unmanagedSelf = Unmanaged.passRetained(self)
        sysexSendRequest.completionRefCon = unmanagedSelf.toOpaque()

        let result: OSStatus
        if customSysExBufferSize >= 4 {
            // We have a reasonable buffer size value, so use it.

            // First, work around a bug with cheap USB-MIDI interfaces.
            // If we are sending to a destination that uses a USB-MIDI driver, it packages the bytes of the buffer
            // into USB-MIDI commands containing exactly 3 bytes of data. If the buffer contains an extra 1 or 2
            // bytes of data, but the sysex hasn't ended, then the driver has to either (1) hold on to those bytes
            // and wait for more data to be sent later, or (2) send them immediately as 1-byte "unparsed" USB-MIDI
            // commands. CoreMIDI's class compliant driver appears to do the latter.
            // Unfortunately, some interfaces don't understand the 1-byte unparsed MIDI messages, and either
            // drop them or get confused.
            // To avoid this issue, round the buffer size down to be a multiple of 3.
            let actualSysExBufferSize = customSysExBufferSize / 3 * 3

            // Calculate a delay between buffers to get the expected speed:
            // maxSysExSpeed is in bytes/second (default 3125)
            // Transmitting B bytes, at speed S, takes a duration of (B/S) sec or (B * 1000 / S) milliseconds.
            //
            // Note that MIDI-OX default settings use 256 byte buffers, with 60 ms between buffers,
            // leading to a speed of 1804 bytes/sec, or 57% of normal speed.
            let realMaxSysExSpeed = (maxSysExSpeed > 0) ? maxSysExSpeed : 3125
            let perBufferDelay = Double(actualSysExBufferSize) / Double(realMaxSysExSpeed)  // seconds

            result = customMIDISendSysex(midiContext, &sysexSendRequest, actualSysExBufferSize, perBufferDelay)
        }
        else {
            // Use CoreMIDI's sender
            result = midiContext.interface.sendSysex(&sysexSendRequest)
        }

        if result != noErr {
            sysexSendRequest.completionRefCon = nil
            unmanagedSelf.release()
            state = .failed
            return false
        }
        else {
            state = .sending
            return true
        }
    }

    @discardableResult public func cancel() -> Bool {
        checkMainQueue()

        guard state == .sending else { return false }

        // Even if we are in state .sending, the request might already be complete, we just haven't
        // gotten didComplete() yet. Wait until we do.
        if sysexSendRequest.complete.boolValue {
            return false
        }
        else {
            // Set the flag so CoreMIDI can see the request is done. The completion will get called
            // and will release us via the refCon. It will call didComplete() again, but that's OK.
            sysexSendRequest.complete = true

            // Tell the world that the request is done, immediately.
            didComplete(.cancelled)

            return true
        }
    }

    public var bytesRemaining: Int {
        return Int(sysexSendRequest.bytesToSend)
    }

    public var totalBytes: Int {
        return dataCount
    }

    public var bytesSent: Int {
        return totalBytes - bytesRemaining
    }

    public var wereAllBytesSent: Bool {
        return bytesRemaining == 0
    }

    // MARK: Private

    private let midiContext: CoreMIDIContext
    private let dataCount: Int
    private let dataPointer: UnsafePointer<UInt8>
    private let maxSysExSpeed: Int
    private var sysexSendRequest: MIDISysexSendRequest

    private enum State {
        case pending    // initialized, but send() has not been called
        case sending    // send() called and is progressing
        case cancelled  // was sending, but cancelled before fully sent
        case sent       // fully sent
        case failed     // send() was called but failed
    }
    private var state = State.pending

    private func didComplete(_ newState: State) {
        checkMainQueue()
        // Transitions only from state == .sending.
        // To make cancellation feasible, this function may be called multiple times,
        // so ensure it's idempotent and only valid state transitions are possible.
        guard state == .sending, newState == .sent || newState == .cancelled else { return }
        state = newState
        delegate?.sysExSendRequestDidFinish(self)
    }

    private func checkMainQueue() {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
    }

}

public protocol SysExSendRequestDelegate: NSObjectProtocol {

    func sysExSendRequestDidFinish(_ sysExSendRequest: SysExSendRequest)

}

// Like MIDISendSysex, but specify a size for each buffer to send, and a delay in seconds between sending each buffer.
private func customMIDISendSysex(_ midiContext: CoreMIDIContext, _ request: UnsafeMutablePointer<MIDISysexSendRequest>, _ bufferSize: Int, _ perBufferDelay: Double) -> OSStatus {
    guard bufferSize >= 3 && bufferSize <= 32767 else { return OSStatus(-50 /* paramErr */) }

    if request.pointee.bytesToSend == 0 {
        request.pointee.complete = true
    }

    if request.pointee.complete.boolValue {
        request.pointee.completionProc(request)
        return OSStatus(noErr)
    }

    var port = MIDIPortRef()
    let status = midiContext.interface.outputPortCreate(midiContext.client, "CustomMIDISendSysex" as CFString, &port)
    if status != noErr {
        return status
    }

    let packetListSize = MemoryLayout.offset(of: \MIDIPacketList.packet.data)! + bufferSize
    var packetListData = Data(count: packetListSize)

    let queue = DispatchQueue(label: "com.snoize.SnoizeMIDI.CustomMIDISendSysex", qos: .userInitiated)

    func sendNextBuffer(port: MIDIPortRef) {
        let packetDataSize = min(Int(request.pointee.bytesToSend), bufferSize)

        packetListData.withUnsafeMutableBytes { (packetListRawBufferPtr: UnsafeMutableRawBufferPointer) in
            let packetListPtr = packetListRawBufferPtr.bindMemory(to: MIDIPacketList.self).baseAddress!

            let curPacket = MIDIPacketListInit(packetListPtr)
            _ = MIDIPacketListAdd(packetListPtr, packetListSize, curPacket, 0, packetDataSize, request.pointee.data)

            _ = midiContext.interface.send(port, request.pointee.destination, packetListPtr)
        }

        request.pointee.data += packetDataSize
        request.pointee.bytesToSend -= UInt32(packetDataSize)
        if request.pointee.bytesToSend == 0 {
            request.pointee.complete = true
        }

        if !request.pointee.complete.boolValue {
            queue.asyncAfter(deadline: .now() + perBufferDelay) {
                sendNextBuffer(port: port)
            }
        }
        else {
            request.pointee.completionProc(request)
            _ = midiContext.interface.portDispose(port)
        }
    }

    queue.async {
        sendNextBuffer(port: port)
    }

    return OSStatus(noErr)
}
