/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
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
        sysExSendRequests.forEach { $0.cancel() }
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
            _ = midiContext.interface.send(outputPort, destination.endpointRef, packetListPtr)
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
        let now = SMGetCurrentHostTime()

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

                    request.send()
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
