/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class PortInputStream: InputStream {

    public override init(midiContext: MIDIContext) {
        super.init(midiContext: midiContext)

        _ = MIDIInputPortCreate(midiContext.midiClient, "Input port" as CFString, midiReadProc, Unmanaged.passUnretained(self).toOpaque(), &inputPort)

        NotificationCenter.default.addObserver(self, selector: #selector(self.midiObjectListChanged(_:)), name: .midiObjectListChanged, object: midiContext)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .midiObjectListChanged, object: midiContext)

        MIDIPortDispose(inputPort)
    }

    public var endpoints: Set<Source> = [] {
        didSet {
            // The closure-based notification observer API is still awkward to use without creating retain cycles.
            // Easier to use ObjC selectors.
            let center = NotificationCenter.default
            oldValue.subtracting(endpoints).forEach { endpoint in
                _ = MIDIPortDisconnectSource(inputPort, endpoint.endpointRef)
                // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.

                // At any time after MIDIPortDisconnectSource(), we can expect that
                // retainForIncomingMIDI() will no longer be called.
                // However, parser(sourceConnectionRefCon:) may still be called, on the main thread,
                // later on; it should not crash or fail, but it may return nil.
                parsersForEndpoints[endpoint] = nil

                center.removeObserver(self, name: .midiObjectDisappeared, object: endpoint)
                center.removeObserver(self, name: .midiObjectWasReplaced, object: endpoint)
            }
            endpoints.subtracting(oldValue).forEach { endpoint in
                parsersForEndpoints[endpoint] = createParser(originatingEndpoint: endpoint)

                center.addObserver(self, selector: #selector(self.endpointDisappeared(_:)), name: .midiObjectDisappeared, object: endpoint)
                center.addObserver(self, selector: #selector(self.endpointWasReplaced(_:)), name: .midiObjectWasReplaced, object: endpoint)

                _ = MIDIPortConnectSource(inputPort, endpoint.endpointRef, Unmanaged.passUnretained(endpoint).toOpaque())

                // At any time after MIDIPortConnectSource(), we can expect
                // retainForIncomingMIDI() and parser(sourceConnectionRefCon:) to be called.
            }
        }
    }

    public func addEndpoint(_ endpoint: Source) {
        endpoints = endpoints.union([endpoint])
    }

    public func removeEndpoint(_ endpoint: Source) {
        endpoints = endpoints.subtracting([endpoint])
    }

    // MARK: InputStream subclass
    // TODO Make this a protocol.

    public override var parsers: [MessageParser] {
        return Array(parsersForEndpoints.values)
    }

    public override func parser(sourceConnectionRefCon: UnsafeMutableRawPointer?) -> MessageParser? {
        // Note: sourceConnectionRefCon points to a Source.
        // We are allowed to return nil if we are no longer listening to this source endpoint.
        guard let refCon = sourceConnectionRefCon else { return nil }
        let endpoint = Unmanaged<Source>.fromOpaque(refCon).takeUnretainedValue()
        return parsersForEndpoints[endpoint]
    }

    public override func streamSource(parser: MessageParser) -> InputStreamSource? {
        return parser.originatingEndpoint?.asInputStreamSource()
    }

    public override var inputSources: [InputStreamSource] {
        midiContext.sources.map { $0.asInputStreamSource() }
    }

    public override var selectedInputSources: Set<InputStreamSource> {
        get {
            return Set(endpoints.map { $0.asInputStreamSource() })
        }
        set {
            endpoints = Set(newValue.compactMap { $0.provider as? Source })
        }
    }

    // MARK: Private

    private var inputPort: MIDIPortRef = 0
    private var parsersForEndpoints: [Source: MessageParser] = [:]
        // TODO Consider making the key endpoint.endpointRef() = MIDIObjectRef to avoid retain and identity issues? But note MessageParser.originatingEndpoint

    @objc private func midiObjectListChanged(_ notification: Notification) {
        if let midiObjectType = notification.userInfo?[MIDIContext.objectType] as? MIDIObjectType,
           midiObjectType == .source {
            postSourceListChangedNotification()
        }
    }

    @objc private func endpointDisappeared(_ notification: Notification) {
        guard let endpoint = notification.object as? Source,
              endpoints.contains(endpoint) else { return }
        removeEndpoint(endpoint)
    }

    @objc private func endpointWasReplaced(_ notification: Notification) {
        guard let endpoint = notification.object as? Source,
              endpoints.contains(endpoint) else { return }
        removeEndpoint(endpoint)
        if let newEndpoint = notification.userInfo?[MIDIContext.objectReplacement] as? Source {
            addEndpoint(newEndpoint)
        }
    }

}
