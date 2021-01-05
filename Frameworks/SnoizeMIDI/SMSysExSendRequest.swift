/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class SMSysExSendRequest: NSObject {

    init?(message: SMSystemExclusiveMessage, endpoint: SMDestinationEndpoint, customSysExBufferSize: Int = 0) {
        self.message = message
        self.customSysExBufferSize = customSysExBufferSize

        guard let fullMessageData = message.fullData else { return nil }
        // MIDISysexSendRequest length is "only" a UInt32
        guard fullMessageData.count < UInt32.max else { return nil }

        // Swift.Data doesn't provide a way to get a long-lived pointer
        // into its bytes. We need to copy the data to a separate buffer,
        // then make the MIDISysexSendRequest take bytes from there.
        dataCount = fullMessageData.count
        let mutableBufferPtr = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: dataCount)
        _ = mutableBufferPtr.initialize(from: fullMessageData)
        dataPointer = UnsafePointer(mutableBufferPtr.baseAddress!)

        maxSysExSpeed = Int(endpoint.maxSysExSpeed())

        sysexSendRequest = MIDISysexSendRequest(
            destination: endpoint.endpointRef(),
            data: dataPointer,
            bytesToSend: UInt32(dataCount),
            complete: false,
            reserved: (0, 0, 0),
            completionProc: { (request: UnsafeMutablePointer<MIDISysexSendRequest>) in
                // NOTE: This is called on CoreMIDI's sysex sending thread.
                guard let refCon = request.pointee.completionRefCon else { return }
                let request = Unmanaged<SMSysExSendRequest>.fromOpaque(refCon).takeRetainedValue()
                DispatchQueue.main.async {
                    request.requestDidComplete()
                }
            },
            completionRefCon: nil)

        super.init()
    }

    deinit {
        dataPointer.deallocate()
    }

    @objc public let message: SMSystemExclusiveMessage
    @objc public let customSysExBufferSize: Int

    @objc public func send() {
        // TODO Retain ourself while pending?  Via Unmanaged

        guard sysexSendRequest.completionRefCon == nil else { return }

        // https://developer.apple.com/forums/thread/80420?answerId=238250022#238250022
        sysexSendRequest.completionRefCon = Unmanaged.passRetained(self).toOpaque()

        let status: OSStatus
        if customSysExBufferSize >= 4 {
            // TODO
            status = -50
        }
        else {
            // Use CoreMIDI's sender
            status = MIDISendSysex(&sysexSendRequest)
        }

        if status != noErr {
            NSLog("MIDISendSysex() returned error \(status)")
            // TODO release self by manually doing the Unmanaged dance above
        }
    }

    @objc public func cancel() -> Bool {
        if sysexSendRequest.complete.boolValue {
            return false
        }
        else {
            sysexSendRequest.complete = true

            // Don't wait for the completion to run, it may be waiting for a while.
            requestDidComplete()
            // TODO May need to release too, and clear the request's refCon

            return true
        }
    }

    @objc public var bytesRemaining: Int {
        return Int(sysexSendRequest.bytesToSend)
    }

    @objc public var totalBytes: Int {
        return dataCount
    }

    @objc public var bytesSent: Int {
        return totalBytes - bytesRemaining
    }

    @objc public var wereAllBytesSent: Bool {
        return bytesRemaining == 0
    }

    // MARK: Internal

    private let dataCount: Int
    private let dataPointer: UnsafePointer<UInt8>
    private let maxSysExSpeed: Int
    private var sysexSendRequest: MIDISysexSendRequest
    private var didComplete = false // TODO Perhaps have a state: pending, sending, complete

    private func requestDidComplete() {
        guard !didComplete else { return }
        didComplete = true
        NotificationCenter.default.post(name: .sysExSendRequestFinished, object: self)
    }

}

// TODO This notification should maybe just be a delegate method.

public extension Notification.Name {

    static let sysExSendRequestFinished = Notification.Name("SMSysExSendRequestFinishedNotification")

}

// TODO Duplicate stuff while migrating from ObjC to Swift
@objc public extension NSNotification {

    static let sysExSendRequestFinished = Notification.Name.sysExSendRequestFinished

}
