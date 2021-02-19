/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa
import SnoizeMIDI

class SpyingInputStream: SnoizeMIDI.InputStream {
    // FUTURE: Perhaps this should not inherit from InputStream, but instead be some kind of
    // plug-in impl object owned by the stream, or an object that wraps InputStream

    private let spyClient: MIDISpyClientRef
    private var spyPort: MIDISpyPortRef?
    private var destinations: Set<Destination> = []
    private var parsersForDestinationEndpointRefs: [MIDIEndpointRef: MessageParser] = [:]

    init?(midiContext: MIDIContext, midiSpyClient: MIDISpyClientRef) {
        spyClient = midiSpyClient

        super.init(midiContext: midiContext)

        guard MIDISpyPortCreate(spyClient, midiReadBlock, &spyPort) == noErr else { return nil }

        NotificationCenter.default.addObserver(self, selector: #selector(self.midiObjectListChanged(_:)), name: .midiObjectListChanged, object: midiContext)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        if let spyPort = spyPort {
            MIDISpyPortDispose(spyPort)
        }

        // Don't tear down the spy client, since others may be using it
    }

    // MARK: InputStream subclass

    override var parsers: [MessageParser] {
        return Array(parsersForDestinationEndpointRefs.values)
    }

    override func parser(sourceConnectionRefCon: UnsafeMutableRawPointer?) -> MessageParser? {
        // Note: sourceConnectionRefCon is a MIDIEndpointRef of a Destination.
        // We are allowed to return nil, e.g. if we are no longer listening to this destination, or if the destination has gone away.
        guard let refCon = sourceConnectionRefCon else { return nil }
        let endpointRef = MIDIEndpointRef(Int(bitPattern: refCon))   // like casting from void* in C
        return parsersForDestinationEndpointRefs[endpointRef]
    }

    override func streamSource(parser: MessageParser) -> InputStreamSource? {
        return parser.originatingEndpoint?.asInputStreamSource()
    }

    override var inputSources: [InputStreamSource] {
        let destinations = midiContext.destinations.filter { !$0.isOwnedByThisProcess }
        return destinations.map { $0.asInputStreamSource() }
    }

    override var selectedInputSources: Set<InputStreamSource> {
        get {
            return Set(destinations.map { $0.asInputStreamSource() })
        }
        set {
            let newDestinations = Set(newValue.compactMap { $0.provider as? Destination })

            let destinationsToAdd = newDestinations.subtracting(destinations)
            let destinationsToRemove = destinations.subtracting(newDestinations)

            for destination in destinationsToRemove {
                removeDestination(destination)
            }

            for destination in destinationsToAdd {
                addDestination(destination)
            }
        }
    }

    // MARK: Private

    private func addDestination(_ destination: Destination) {
        guard !destinations.contains(destination) else { return }

        let parser = createParser(originatingEndpoint: destination)
        parsersForDestinationEndpointRefs[destination.endpointRef] = parser

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.destinationDisappeared(_:)), name: .midiObjectDisappeared, object: destination)
        center.addObserver(self, selector: #selector(self.destinationWasReplaced(_:)), name: .midiObjectWasReplaced, object: destination)

        _ = destinations.insert(destination)

        let connRefCon = UnsafeMutableRawPointer(bitPattern: Int(destination.endpointRef))   // like casting to void* in C
        let status = MIDISpyPortConnectDestination(spyPort, destination.endpointRef, connRefCon)
        if status != noErr {
            NSLog("Error from MIDISpyPortConnectDestination: \(status)")
        }
    }

    private func removeDestination(_ destination: Destination) {
        guard destinations.contains(destination) else { return }

        let status = MIDISpyPortDisconnectDestination(spyPort, destination.endpointRef)
        if status != noErr {
            NSLog("Error from MIDISpyPortDisconnectDestination: \(status)")
            // An error can happen in normal circumstances (if the endpoint has disappeared), so ignore it.
        }

        parsersForDestinationEndpointRefs[destination.endpointRef] = nil

        let center = NotificationCenter.default
        center.removeObserver(self, name: .midiObjectDisappeared, object: destination)
        center.removeObserver(self, name: .midiObjectWasReplaced, object: destination)

        destinations.remove(destination)
    }

    @objc private func midiObjectListChanged(_ notification: Notification) {
        if let midiObjectType = notification.userInfo?[MIDIContext.objectType] as? MIDIObjectType,
           midiObjectType == .destination {
            sourceListChanged()
        }
    }

    @objc private func destinationDisappeared(_ notification: Notification) {
        guard let destination = notification.object as? Destination,
              destinations.contains(destination) else { return }
        removeDestination(destination)
    }

    @objc private func destinationWasReplaced(_ notification: Notification) {
        guard let destination = notification.object as? Destination,
              destinations.contains(destination) else { return }
        removeDestination(destination)
        if let newDestination = notification.userInfo?[MIDIContext.objectReplacement] as? Destination {
            addDestination(newDestination)
        }
    }

}
