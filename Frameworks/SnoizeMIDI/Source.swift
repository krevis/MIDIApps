/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import CoreMIDI

public class Source: Endpoint, CoreMIDIObjectListable {

    // MARK: CoreMIDIObjectListable

    static let midiObjectType = MIDIObjectType.source
    static func midiObjectCount(_ context: CoreMIDIContext) -> Int {
        context.interface.getNumberOfSources()
    }
    static func midiObjectSubscript(_ context: CoreMIDIContext, _ index: Int) -> MIDIObjectRef {
        context.interface.getSource(index)
    }

    override func midiPropertyChanged(_ property: CFString) {
        super.midiPropertyChanged(property)

        if property == kMIDIPropertyConnectionUniqueID || property == kMIDIPropertyName {
            // This may affect our displayName
            midiContext.forcePropertyChanged(Self.midiObjectType, midiObjectRef, kMIDIPropertyDisplayName)
        }

        if property == kMIDIPropertyDisplayName {
            // FUTURE: Something more targeted would be nice.
            midiContext.postObjectListChangedNotification(Self.midiObjectType)
        }
    }

    // MARK: Additional API

    public func remove() {
        // Only possible for virtual endpoints owned by this process
        guard midiObjectRef != 0 && isOwnedByThisProcess else { return }

        _ = midiContext.interface.endpointDispose(endpointRef)

        // This object continues to live in the endpoint list until CoreMIDI notifies us, at which time we remove it.
        // There is no need for us to remove it immediately. (In fact, it's better that we don't;
        // it's possible that CoreMIDI has enqueued notifications to us about the endpoint, including the notification
        // that it was added in the first place. If we get that AFTER we remove it from the list, we'll add it again.)
    }

}

extension MIDIContext {

    public func createVirtualSource(name: String, uniqueID: MIDIUniqueID) -> Source? {
        // If uniqueID is 0, we'll use the unique ID that CoreMIDI generates for us

        var newEndpointRef: MIDIEndpointRef = 0

        // Ensure the sources list is up to date first, since it gets lazily loaded
        _ = self.sources

        // Now create the virtual source in CoreMIDI
        guard interface.sourceCreate(client, name as CFString, &newEndpointRef) == noErr else { return nil }

        // We want to get at the Source immediately, to configure it.
        // CoreMIDI will send us a notification that something was added,
        // but that won't arrive until later. So manually add the new Source,
        // trusting that we won't add it again later.
        guard let source = addedVirtualSource(midiObjectRef: newEndpointRef) else { return nil }

        if uniqueID != 0 {
            source.uniqueID = uniqueID
        }
        while source.uniqueID == 0 {
            // CoreMIDI didn't assign a unique ID to this endpoint, so we should generate one ourself
            source.uniqueID = generateNewUniqueID()
        }

        source.manufacturer = "Snoize"
        source.model = name

        return source
    }

}
