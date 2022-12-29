/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
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

        if let spyPort {
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
        return parser.originatingEndpoint?.asInputStreamSource
    }

    override var inputSources: [InputStreamSource] {
        let destinations = midiContext.destinations.filter { !$0.isOwnedByThisProcess }
        return destinations.map(\.asInputStreamSource)
    }

    override var selectedInputSources: Set<InputStreamSource> {
        get {
            Set(destinations.map(\.asInputStreamSource))
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
