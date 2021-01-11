/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class SpyingInputStream: SMInputStream {
    // TODO Perhaps this should not inherit from the stream, but use a protocol instead

    private let spyClient: MIDISpyClientRef
    private var spyPort: MIDISpyPortRef?
    private var endpoints: Set<SMDestinationEndpoint> = []
    private var parsersForEndpoints = NSMapTable<SMDestinationEndpoint, SMMessageParser>.weakToStrongObjects()

    init?(midiSpyClient: MIDISpyClientRef) {
        spyClient = midiSpyClient

        super.init()

        let status = MIDISpyPortCreate(spyClient, midiReadProc, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &spyPort)
        if status != noErr {
            NSLog("Error from MIDISpyPortCreate: \(status)")
            return nil
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.endpointListChanged(_:)), name: .SMMIDIObjectListChanged, object: SMDestinationEndpoint.self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        if let spyPort = spyPort {
            MIDISpyPortDispose(spyPort)
        }

        // Don't tear down the spy client, since others may be using it
    }

    // MARK: SMInputStream subclass

    override var parsers: [SMMessageParser] {
        return parsersForEndpoints.objectEnumerator()?.allObjects as? [SMMessageParser] ?? []
    }

    override func parser(sourceConnectionRefCon: UnsafeMutableRawPointer?) -> SMMessageParser? {
        // note: refCon is an SMDestinationEndpoint*.
        // We are allowed to return nil if we are no longer listening to this source endpoint.
        guard let refCon = sourceConnectionRefCon else { return nil }
        let endpoint = Unmanaged<SMDestinationEndpoint>.fromOpaque(refCon).takeUnretainedValue()
        return parsersForEndpoints.object(forKey: endpoint)
    }

    override func streamSource(parser: SMMessageParser) -> SMInputStreamSource? {
        return parser.originatingEndpoint
    }

    override func retainForIncomingMIDI(sourceConnectionRefCon: UnsafeMutableRawPointer?) {
        super.retainForIncomingMIDI(sourceConnectionRefCon: sourceConnectionRefCon)

        // Retain the endpoint too, since we use it as a key in parser(sourceConnectionRefCon:)
        if let refCon = sourceConnectionRefCon {
            _ = Unmanaged<SMDestinationEndpoint>.fromOpaque(refCon).retain()
        }
    }

    override func releaseForIncomingMIDI(sourceConnectionRefCon: UnsafeMutableRawPointer?) {
        // release the endpoint that we retained earlier
        if let refCon = sourceConnectionRefCon {
            Unmanaged<SMDestinationEndpoint>.fromOpaque(refCon).release()
        }

        super.releaseForIncomingMIDI(sourceConnectionRefCon: sourceConnectionRefCon)
    }

    override var inputSources: [SMInputStreamSource] {
        let destinationEndpoints = SMDestinationEndpoint.destinationEndpoints() ?? []
        return destinationEndpoints.filter { !$0.isOwnedByThisProcess() }
    }

    override var selectedInputSources: Set<AnyHashable> {
        get {
            return endpoints
        }
        set {
            let endpointsToAdd = newValue.subtracting(endpoints)
            let endpointsToRemove = (endpoints as Set<AnyHashable>).subtracting(newValue)

            for endpoint in endpointsToRemove {
                if let destinationEndpoint = endpoint as? SMDestinationEndpoint {
                    removeEndpoint(destinationEndpoint)
                }
            }

            for endpoint in endpointsToAdd {
                if let destinationEndpoint = endpoint as? SMDestinationEndpoint {
                    addEndpoint(destinationEndpoint)
                }
            }
        }
    }

    // MARK: Private

    private func addEndpoint(_ endpoint: SMDestinationEndpoint) {
        guard !endpoints.contains(endpoint) else { return }

        let parser = createParser(originatingEndpoint: endpoint)
        parsersForEndpoints.setObject(parser, forKey: endpoint)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.endpointDisappeared(_:)), name: .SMMIDIObjectDisappeared, object: endpoint)
        center.addObserver(self, selector: #selector(self.endpointWasReplaced(_:)), name: .SMMIDIObjectWasReplaced, object: endpoint)

        _ = endpoints.insert(endpoint)

        let status = MIDISpyPortConnectDestination(spyPort, endpoint.endpointRef(), Unmanaged.passUnretained(endpoint).toOpaque())
        if status != noErr {
            NSLog("Error from MIDISpyPortConnectDestination: \(status)")
        }
    }

    private func removeEndpoint(_ endpoint: SMDestinationEndpoint) {
        guard endpoints.contains(endpoint) else { return }

        let status = MIDISpyPortDisconnectDestination(spyPort, endpoint.endpointRef())
        if status != noErr {
            NSLog("Error from MIDISpyPortDisconnectDestination: \(status)")
            // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.
        }

        parsersForEndpoints.removeObject(forKey: endpoint)

        let center = NotificationCenter.default
        center.removeObserver(self, name: .SMMIDIObjectDisappeared, object: endpoint)
        center.removeObserver(self, name: .SMMIDIObjectWasReplaced, object: endpoint)

        endpoints.remove(endpoint)
    }

    @objc private func endpointListChanged(_ notification: Notification) {
        self.postSourceListChangedNotification()
    }

    @objc private func endpointDisappeared(_ notification: Notification) {
        guard let endpoint = notification.object as? SMDestinationEndpoint,
              endpoints.contains(endpoint) else { return }

        removeEndpoint(endpoint)
        postSelectedInputStreamSourceDisappearedNotification(source: endpoint)
    }

    @objc private func endpointWasReplaced(_ notification: Notification) {
        guard let endpoint = notification.object as? SMDestinationEndpoint,
              endpoints.contains(endpoint) else { return }

        removeEndpoint(endpoint)
        if let newEndpoint = notification.userInfo?[SMMIDIObjectReplacement] as? SMDestinationEndpoint {
            addEndpoint(newEndpoint)
        }
    }

}
