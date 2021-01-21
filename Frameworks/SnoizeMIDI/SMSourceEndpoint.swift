/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CoreMIDI

@objc public class SMSourceEndpoint: SMEndpoint {

    @objc public class var sourceEndpoints: [SMSourceEndpoint] {
        (allObjectsInOrder as? [SMSourceEndpoint]) ?? []
    }

    @objc public class func findSourceEndpoint(uniqueID: MIDIUniqueID) -> SMSourceEndpoint? {
        findObject(uniqueID: uniqueID)
        // TODO Better name
    }

    @objc public class func findSourceEndpoint(name: String) -> SMSourceEndpoint? {
        findObject(name: name)
        // TODO Better name
    }

    @objc public class func findSourceEndpoint(endpointRef: MIDIEndpointRef) -> SMSourceEndpoint? {
        findObject(objectRef: endpointRef)
        // TODO This is unused, see if we really need it
    }

    public class func createVirtualSourceEndpoint(name: String, uniqueID: MIDIUniqueID) -> SMSourceEndpoint? {
        // If newUniqueID is 0, we'll use the unique ID that CoreMIDI generates for us

        var endpoint: SMSourceEndpoint?
        let client = SMClient.sharedClient!

        // We are going to be making a lot of changes, so turn off external notifications
        // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
        do {
            let wasPostingExternalNotification = client.postsExternalSetupChangeNotification
            client.postsExternalSetupChangeNotification = false
            defer { client.postsExternalSetupChangeNotification = wasPostingExternalNotification }

            var newEndpointRef: MIDIEndpointRef = 0
            guard MIDISourceCreate(client.midiClient, name as CFString, &newEndpointRef) == noErr else { return nil }

            // We want to get at the SMEndpoint immediately.
            // CoreMIDI will send us a notification that something was added, and then we will create an SMSourceEndpoint.
            // However, the notification from CoreMIDI is posted in the run loop's main mode, and we don't want to wait for it to be run.
            // So we need to manually add the new endpoint, now.
            endpoint = immediatelyAddObject(objectRef: newEndpointRef) as? SMSourceEndpoint
            if let endpoint = endpoint {
                endpoint.setOwnedByThisProcess()

                if uniqueID != 0 {
                    endpoint.uniqueID = uniqueID
                }
                if endpoint.uniqueID == 0 {
                    // CoreMIDI didn't assign a unique ID to this endpoint, so we should generate one ourself
                    // TODO Figure out how to do this
                    /*
                    var success = false
                    while !success {
                        success = endpoint.setUniqueID(SMMIDIObject.generateNewUniqueID())
                    }*/
                }

                endpoint.manufacturerName = "Snoize"
            }

            // End the scope, restoring postsExternaSetupChangeNotification,
            // before we do the last endpoint modification, so one setup change
            // notification will still happen
        }

        endpoint?.modelName = client.name

        return endpoint
    }

    // MARK: SMMIDIObject required overrides

    public override class var midiObjectType: MIDIObjectType {
        MIDIObjectType.source
    }

    public override class var midiObjectCount: Int {
        MIDIGetNumberOfSources()
    }

    public override class func midiObject(at index: Int) -> MIDIObjectRef {
        MIDIGetSource(index)
    }

    // MARK: SMEndpoint required overrides

    public override class func endpointCount(forEntity entity: MIDIEntityRef) -> Int {
        MIDIEntityGetNumberOfSources(entity)
    }

    public override class func endpointRef(at index: Int, forEntity entity: MIDIEntityRef) -> MIDIEndpointRef {
        MIDIEntityGetSource(entity, index)
    }

}
