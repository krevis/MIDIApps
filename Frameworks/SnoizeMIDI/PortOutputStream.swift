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

public class PortOutputStream: OutputStream {

    public override init(midiContext: MIDIContext) {
        outputPort = 0
        _ = midiContext.interface.outputPortCreate(midiContext.client, "Output Port" as CFString, &outputPort)
        super.init(midiContext: midiContext)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        _ = midiContext.interface.portDispose(outputPort)
    }

    public weak var delegate: PortOutputStreamDelegate?

    public var destinations: Set<Destination> = [] {
        didSet {
            // The closure-based notification observer API is still awkward to use without creating retain cycles.
            // Easier to use ObjC selectors.
            let center = NotificationCenter.default
            oldValue.subtracting(destinations).forEach {
                center.removeObserver(self, name: .midiObjectDisappeared, object: $0)
                center.removeObserver(self, name: .midiObjectWasReplaced, object: $0)
            }
            destinations.subtracting(oldValue).forEach {
                center.addObserver(self, selector: #selector(self.destinationDisappeared(notification:)), name: .midiObjectDisappeared, object: $0)
                center.addObserver(self, selector: #selector(self.destinationWasReplaced(notification:)), name: .midiObjectWasReplaced, object: $0)
            }
        }
    }

    public var sendsSysExAsynchronously: Bool = false

    public func cancelPendingSysExSendRequests() {
        sysExSendRequests.forEach { _ = $0.cancel() }
    }

    public var pendingSysExSendRequests: [SysExSendRequest] {
        return Array(sysExSendRequests)
    }

    public var customSysExBufferSize: Int = 0

    // MARK: OutputStream overrides

    public override func takeMIDIMessages(_ messages: [Message]) {
        if sendsSysExAsynchronously {
            // Find the messages which are sysex and which have timestamps which are <= now,
            // and send them using MIDISendSysex(). Other messages get sent normally.
            let (asyncSysexMessages, normalMessages) = splitMessagesByAsyncSysex(messages)
            sendSysExMessagesAsynchronously(asyncSysexMessages)
            super.takeMIDIMessages(normalMessages)
        }
        else {
            super.takeMIDIMessages(messages)
        }
    }

    // MARK: OutputStream subclass-implementation methods

    override func send(_ packetListPtr: UnsafePointer<MIDIPacketList>) {
        for destination in destinations {
            _ = MIDISend(outputPort, destination.endpointRef, packetListPtr)
        }
    }

    // MARK: Private

    private var outputPort: MIDIPortRef

    @objc private func destinationDisappeared(notification: Notification) {
        if let endpoint = notification.object as? Destination {
            destinationDisappeared(endpoint)
        }
    }

    private func destinationDisappeared(_ destination: Destination) {
        guard destinations.contains(destination) else { return }
        var newDestinations = destinations
        newDestinations.remove(destination)
        destinations = newDestinations
        delegate?.portOutputStreamDestinationDisappeared(self)
    }

    @objc private func destinationWasReplaced(notification: Notification) {
        if let destination = notification.object as? Destination,
           let replacement = notification.userInfo?[MIDIContext.objectReplacement] as? Destination {
            destinationWasReplaced(destination, replacement)
        }
    }

    private func destinationWasReplaced(_ destination: Destination, _ replacement: Destination) {
        guard destinations.contains(destination) else { return }
        var newDestinations = destinations
        newDestinations.remove(destination)
        newDestinations.insert(replacement)
        destinations = newDestinations
    }

    private func splitMessagesByAsyncSysex(_ messages: [Message]) -> ([SystemExclusiveMessage], [Message]) {
        // FUTURE: This should use `stablePartition`, when that gets added
        // to the Swift standard library.

        var asyncSysexMessages: [SystemExclusiveMessage] = []
        var normalMessages: [Message] = []
        let now = AudioGetCurrentHostTime()

        for message in messages {
            if let sysexMessage = message as? SystemExclusiveMessage,
               sysexMessage.hostTimeStamp <= now {
                asyncSysexMessages.append(sysexMessage)
            }
            else {
                normalMessages.append(message)
            }
        }

        return (asyncSysexMessages, normalMessages)
    }

    private var sysExSendRequests = Set<SysExSendRequest>()

    private func sendSysExMessagesAsynchronously(_ messages: [SystemExclusiveMessage]) {
        for message in messages {
            for destination in destinations {
                if let request = SysExSendRequest(message: message, destination: destination, customSysExBufferSize: customSysExBufferSize) {
                    sysExSendRequests.insert(request)
                    request.delegate = self

                    delegate?.portOutputStream(self, willBeginSendingSysEx: request)

                    _ = request.send()
                }
            }
        }
    }

}

extension PortOutputStream: SysExSendRequestDelegate {

    public func sysExSendRequestDidFinish(_ sysExSendRequest: SysExSendRequest) {
        sysExSendRequests.remove(sysExSendRequest)

        delegate?.portOutputStream(self, didEndSendingSysEx: sysExSendRequest)
    }

}

public protocol PortOutputStreamDelegate: NSObjectProtocol {

    // Sent when one of the stream's destination endpoints is removed by the system.
    func portOutputStreamDestinationDisappeared(_ stream: PortOutputStream)

    // Sent when sysex begins sending and ends sending.
    func portOutputStream(_ stream: PortOutputStream, willBeginSendingSysEx request: SysExSendRequest)
    func portOutputStream(_ stream: PortOutputStream, didEndSendingSysEx request: SysExSendRequest)

}
