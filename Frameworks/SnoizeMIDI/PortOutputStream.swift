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

@objc public class PortOutputStream: OutputStream {

    public var endpoints: Set<Destination> = [] {
        didSet {
            // The closure-based notification observer API is still awkward to use without creating retain cycles.
            // Easier to use ObjC selectors.
            let center = NotificationCenter.default
            oldValue.subtracting(endpoints).forEach {
                center.removeObserver(self, name: .midiObjectDisappeared, object: $0)
                center.removeObserver(self, name: .midiObjectWasReplaced, object: $0)
            }
            endpoints.subtracting(oldValue).forEach {
                center.addObserver(self, selector: #selector(self.endpointDisappeared(notification:)), name: .midiObjectDisappeared, object: $0)
                center.addObserver(self, selector: #selector(self.endpointWasReplaced(notification:)), name: .midiObjectWasReplaced, object: $0)
            }
        }
    }

    @objc public var sendsSysExAsynchronously: Bool = false

    @objc public func cancelPendingSysExSendRequests() {
        sysExSendRequests.forEach { _ = $0.cancel() }
    }

    @objc public var pendingSysExSendRequests: [SysExSendRequest] {
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
    // TODO Just ignore this error, we did it for input stream port create

    public static func newPortOutputStream(midiContext: MIDIContext) -> PortOutputStream? {
        var port: MIDIPortRef = 0
        let status = MIDIOutputPortCreate(midiContext.midiClient, "Output Port" as CFString, &port)
        guard status == noErr else { return nil }

        return PortOutputStream(midiContext: midiContext, port: port)
    }

    private init(midiContext: MIDIContext, port: MIDIPortRef) {
        outputPort = port
        super.init(midiContext: midiContext)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        MIDIPortDispose(outputPort)
    }

    // MARK: OutputStream overrides

    @objc public override func takeMIDIMessages(_ messages: [Message]) {
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
        for endpoint in endpoints {
            _ = MIDISend(outputPort, endpoint.endpointRef, packetListPtr)
        }
    }

    // MARK: Private

    private var outputPort: MIDIPortRef

    @objc private func endpointDisappeared(notification: Notification) {
        if let endpoint = notification.object as? Destination {
            endpointDisappeared(endpoint)
        }
    }

    private func endpointDisappeared(_ endpoint: Destination) {
        guard endpoints.contains(endpoint) else { return }
        var newEndpoints = endpoints
        newEndpoints.remove(endpoint)
        endpoints = newEndpoints
        NotificationCenter.default.post(name: .portOutputStreamEndpointDisappeared, object: self)
    }

    @objc private func endpointWasReplaced(notification: Notification) {
        if let endpoint = notification.object as? Destination,
           let replacement = notification.userInfo?[MIDIContext.objectReplacement] as? Destination {
            endpointWasReplaced(endpoint, replacement)
        }
    }

    private func endpointWasReplaced(_ endpoint: Destination, _ replacement: Destination) {
        guard endpoints.contains(endpoint) else { return }
        var newEndpoints = endpoints
        newEndpoints.remove(endpoint)
        newEndpoints.insert(replacement)
        endpoints = newEndpoints
    }

    private func splitMessagesByAsyncSysex(_ messages: [Message]) -> ([SystemExclusiveMessage], [Message]) {
        // Note: Someday this should use `stablePartition`, when that gets added
        // to the Swift standard library.

        var asyncSysexMessages: [SystemExclusiveMessage] = []
        var normalMessages: [Message] = []
        let now = AudioGetCurrentHostTime()

        for message in messages {
            if let sysexMessage = message as? SystemExclusiveMessage,
               sysexMessage.timeStamp <= now {
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
        let center = NotificationCenter.default

        for message in messages {
            for endpoint in endpoints {
                if let request = SysExSendRequest(message: message, endpoint: endpoint, customSysExBufferSize: customSysExBufferSize) {
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
    // userInfo has key "sendRequest", object SysExSendRequest
    // TODO Formalize that

}

// TODO Duplicate stuff while migrating from ObjC to Swift
/*
@objc public extension NSNotification {

    static let portOutputStreamEndpointDisappeared = Notification.Name.portOutputStreamEndpointDisappeared
    static let portOutputStreamSysExSendWillBegin = Notification.Name.portOutputStreamSysExSendWillBegin
    static let portOutputStreamSysExSendDidEnd = Notification.Name.portOutputStreamSysExSendDidEnd

}
*/
