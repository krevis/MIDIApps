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

@objc public class SMPortOutputStream: SMOutputStream {

    @objc public var endpoints: Set<SMDestinationEndpoint> = [] {
        didSet {
            // The closure-based notification observer API is still awkward to use without creating retain cycles.
            // Easier to use ObjC selectors.
            let center = NotificationCenter.default
            oldValue.subtracting(endpoints).forEach {
                center.removeObserver(self, name: .SMMIDIObjectDisappeared, object: $0)
                center.removeObserver(self, name: .SMMIDIObjectWasReplaced, object: $0)
            }
            endpoints.subtracting(oldValue).forEach {
                center.addObserver(self, selector: #selector(self.endpointDisappeared(notification:)), name: .SMMIDIObjectDisappeared, object: $0)
                center.addObserver(self, selector: #selector(self.endpointWasReplaced(notification:)), name: .SMMIDIObjectWasReplaced, object: $0)
            }
        }
    }

    @objc public var sendsSysExAsynchronously: Bool = false

    @objc public func cancelPendingSysExSendRequests() {
        sysExSendRequests.forEach { _ = $0.cancel() }
    }

    @objc public var pendingSysExSendRequests: [SMSysExSendRequest] {
        return Array(sysExSendRequests)
    }

    @objc public var customSysExBufferSize: Int = 0

    // It's possible (although unlikely) that creating the output port fails.
    // In ObjC we could have made init return nil, but apparently that is not
    // easy to do in Swift (especially to make it usable by ObjC):
    // https://stackoverflow.com/questions/26833845/parameterless-failable-initializer-for-an-nsobject-subclass
    // https://stackoverflow.com/questions/38311365/swift-failable-initializer-init-cannot-override-a-non-failable-initializer
    // Best I can do is to make a new static function that returns a new instance, or nil.
    // Yuck!

    @objc public static func newPortOutputStream() -> SMPortOutputStream? {
        guard let client = SMClient.sharedClient else { return nil }

        var port: MIDIPortRef = 0
        let status = MIDIOutputPortCreate(client.midiClient, "Output Port" as CFString, &port)
        guard status == noErr else { return nil }

        return SMPortOutputStream(port: port)
    }

    private init(port: MIDIPortRef) {
        outputPort = port
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        MIDIPortDispose(outputPort)
    }

    // MARK: SMOutputStream overrides

    @objc public override func takeMIDIMessages(_ messages: [SMMessage]) {
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

    // MARK: SMOutputStream subclass-implementation methods

    override func send(_ packetListPtr: UnsafePointer<MIDIPacketList>) {
        for endpoint in endpoints {
            _ = MIDISend(outputPort, endpoint.endpointRef, packetListPtr)
        }
    }

    // MARK: Private

    private var outputPort: MIDIPortRef

    @objc private func endpointDisappeared(notification: Notification) {
        if let endpoint = notification.object as? SMDestinationEndpoint {
            endpointDisappeared(endpoint)
        }
    }

    private func endpointDisappeared(_ endpoint: SMDestinationEndpoint) {
        guard endpoints.contains(endpoint) else { return }
        var newEndpoints = endpoints
        newEndpoints.remove(endpoint)
        endpoints = newEndpoints
        NotificationCenter.default.post(name: .portOutputStreamEndpointDisappeared, object: self)
    }

    @objc private func endpointWasReplaced(notification: Notification) {
        if let endpoint = notification.object as? SMDestinationEndpoint,
           let replacement = notification.userInfo?[SMMIDIObjectReplacement] as? SMDestinationEndpoint {
            endpointWasReplaced(endpoint, replacement)
        }
    }

    private func endpointWasReplaced(_ endpoint: SMDestinationEndpoint, _ replacement: SMDestinationEndpoint) {
        guard endpoints.contains(endpoint) else { return }
        var newEndpoints = endpoints
        newEndpoints.remove(endpoint)
        newEndpoints.insert(replacement)
        endpoints = newEndpoints
    }

    private func splitMessagesByAsyncSysex(_ messages: [SMMessage]) -> ([SMSystemExclusiveMessage], [SMMessage]) {
        // Note: Someday this should use `stablePartition`, when that gets added
        // to the Swift standard library.

        var asyncSysexMessages: [SMSystemExclusiveMessage] = []
        var normalMessages: [SMMessage] = []
        let now = AudioGetCurrentHostTime()

        for message in messages {
            if let sysexMessage = message as? SMSystemExclusiveMessage,
               sysexMessage.timeStamp <= now {
                asyncSysexMessages.append(sysexMessage)
            }
            else {
                normalMessages.append(message)
            }
        }

        return (asyncSysexMessages, normalMessages)
    }

    private var sysExSendRequests = Set<SMSysExSendRequest>()

    private func sendSysExMessagesAsynchronously(_ messages: [SMSystemExclusiveMessage]) {
        let center = NotificationCenter.default

        for message in messages {
            for endpoint in endpoints {
                if let request = SMSysExSendRequest(message: message, endpoint: endpoint, customSysExBufferSize: customSysExBufferSize) {
                    sysExSendRequests.insert(request)

                    var token: NSObjectProtocol?
                    token = center.addObserver(forName: .sysExSendRequestFinished, object: request, queue: nil) { [weak self] _ in
                        guard let self = self else { return }

                        center.removeObserver(token!)
                        token = nil  // Required to break a retain cycle!

                        self.sysExSendRequests.remove(request)

                        center.post(name: .portOutputStreamSysExSendDidEnd, object: self, userInfo: ["sendRequest": request])
                    }

                    center.post(name: .portOutputStreamSysExSendWillBegin, object: self, userInfo: ["sendRequest": request])

                    _ = request.send()
                }
            }
        }
    }

}

// TODO These notifications should just be delegate methods.

public extension Notification.Name {

    static let portOutputStreamEndpointDisappeared = Notification.Name("SMPortOutputStreamEndpointDisappearedNotification")
    // Posted when one of the stream's destination endpoints is removed by the system.

    static let portOutputStreamSysExSendWillBegin = Notification.Name("SMPortOutputStreamWillStartSysExSendNotification")
    static let portOutputStreamSysExSendDidEnd = Notification.Name("SMPortOutputStreamFinishedSysExSendNotification")
    // userInfo has key "sendRequest", object SMSysExSendRequest
    // TODO Formalize that

}

// TODO Duplicate stuff while migrating from ObjC to Swift
@objc public extension NSNotification {

    static let portOutputStreamEndpointDisappeared = Notification.Name.clientSetupChanged
    static let portOutputStreamSysExSendWillBegin = Notification.Name.portOutputStreamSysExSendWillBegin
    static let portOutputStreamSysExSendDidEnd = Notification.Name.portOutputStreamSysExSendDidEnd

}
