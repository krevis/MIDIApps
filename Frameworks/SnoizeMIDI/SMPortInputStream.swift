/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class SMPortInputStream: SMInputStream {

    @objc public override init() {
        guard let client = SMClient.sharedClient else { fatalError() }

        super.init()

        let status = MIDIInputPortCreate(client.midiClient, "Input port" as CFString, midiReadProc, Unmanaged.passUnretained(self).toOpaque(), &inputPort)
        if status != noErr {
            // TODO how to handle?
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.endpointListChanged(_:)), name: .SMMIDIObjectListChanged, object: SMSourceEndpoint.self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .SMMIDIObjectListChanged, object: SMSourceEndpoint.self)

        MIDIPortDispose(inputPort)
    }

    @objc public var endpoints: Set<SMSourceEndpoint> = [] {
        didSet {
            // The closure-based notification observer API is still awkward to use without creating retain cycles.
            // Easier to use ObjC selectors.
            let center = NotificationCenter.default
            oldValue.subtracting(endpoints).forEach { endpoint in
                _ = MIDIPortDisconnectSource(inputPort, endpoint.endpointRef())
                // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.

                // At any time after MIDIPortDisconnectSource(), we can expect that
                // retainForIncomingMIDIWithSourceConnectionRefCon() will no longer be called.
                // However, parserForSourceConnectionRefCon() may still be called, on the main thread,
                // later on; it should not crash or fail, but it may return nil.
                parsersForEndpoints.removeValue(forKey: endpoint)

                center.removeObserver(self, name: .SMMIDIObjectDisappeared, object: endpoint)
                center.removeObserver(self, name: .SMMIDIObjectWasReplaced, object: endpoint)
            }
            endpoints.subtracting(oldValue).forEach { endpoint in
                parsersForEndpoints[endpoint] = createParser(originatingEndpoint: endpoint)

                center.addObserver(self, selector: #selector(self.endpointDisappeared(_:)), name: .SMMIDIObjectDisappeared, object: endpoint)
                center.addObserver(self, selector: #selector(self.endpointWasReplaced(_:)), name: .SMMIDIObjectWasReplaced, object: endpoint)

                _ = MIDIPortConnectSource(inputPort, endpoint.endpointRef(), Unmanaged.passUnretained(endpoint).toOpaque())

                // At any time after MIDIPortConnectSource(), we can expect
                // retainForIncomingMIDIWithSourceConnectionRefCon()
                // and parserForSourceConnectionRefCon() to be called.
            }
        }
    }

    @objc public func addEndpoint(_ endpoint: SMSourceEndpoint) {
        endpoints = endpoints.union([endpoint])
    }

    @objc public func removeEndpoint(_ endpoint: SMSourceEndpoint) {
        endpoints = endpoints.subtracting([endpoint])
    }

    // MARK: SMInputStream subclass
    // TODO Make this a protocol.

    override internal var parsers: [SMMessageParser] {
        return Array(parsersForEndpoints.values)
    }

    override internal func parser(sourceConnectionRefCon: UnsafeMutableRawPointer) -> SMMessageParser? {
        // Note: sourceConnectionRefCon points to a SMSourceEndpoint.
        // We are allowed to return nil if we are no longer listening to this source endpoint.
        let endpoint = Unmanaged<SMSourceEndpoint>.fromOpaque(sourceConnectionRefCon).takeUnretainedValue()
        return parsersForEndpoints[endpoint]
    }

    override internal func streamSource(parser: SMMessageParser) -> SMInputStreamSource? {
        return parser.originatingEndpoint()
    }

    override public var inputSources: [SMInputStreamSource] {
        SMSourceEndpoint.sourceEndpoints()
    }

    override public var selectedInputSources: Set<AnyHashable> { // TODO Should be typed better
        get {
            endpoints
        }
        set {
            if let newEndpoints = newValue as? Set<SMSourceEndpoint> {
                endpoints = newEndpoints
            }
        }
    }

    // MARK: Private

    private var inputPort: MIDIPortRef = 0
    private var parsersForEndpoints: [SMSourceEndpoint: SMMessageParser] = [:]
        // TODO Consider making the key endpoint.endpointRef() = MIDIObjectRef to avoid retain and identity issues? But note SMMessageParser.originatingEndpoint

    @objc private func endpointListChanged(_ notification: Notification) {
        postSourceListChangedNotification()
    }

    @objc private func endpointDisappeared(_ notification: Notification) {
        if let endpoint = notification.object as? SMSourceEndpoint,
           endpoints.contains(endpoint) {
            removeEndpoint(endpoint)
            postSelectedInputStreamSourceDisappearedNotification(source: endpoint)
        }
    }

    @objc private func endpointWasReplaced(_ notification: Notification) {
        if let oldEndpoint = notification.object as? SMSourceEndpoint,
           endpoints.contains(oldEndpoint),
           let newEndpoint = notification.userInfo?[SMMIDIObjectReplacement] as? SMSourceEndpoint {
            removeEndpoint(oldEndpoint)
            addEndpoint(newEndpoint)
        }
    }

}
