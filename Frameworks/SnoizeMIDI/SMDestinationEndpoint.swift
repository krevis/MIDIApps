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

@objc public class SMDestinationEndpoint: SMEndpoint {

    @objc public class var destinationEndpoints: [SMDestinationEndpoint] {
        let endpoints = (allObjectsInOrder() as? [SMDestinationEndpoint]) ?? []
        return endpoints.filter { $0 != cachedSysExSpeedWorkaroundEndpoint }
    }

    @objc public class func findDestinationEndpoint(uniqueID: MIDIUniqueID) -> SMDestinationEndpoint? {
        find(withUniqueID: uniqueID) as? SMDestinationEndpoint
        // TODO Better name
    }

    @objc public class func findDestinationEndpoint(name: String) -> SMDestinationEndpoint? {
        find(withName: name) as? SMDestinationEndpoint
        // TODO Better name
    }

    @objc public class func findDestinationEndpoint(endpointRef: MIDIEndpointRef) -> SMDestinationEndpoint? {
        findObject(withObjectRef: endpointRef) as? SMDestinationEndpoint
        // TODO Better name, is this used?
    }

    public class func createVirtualDestinationEndpoint(name: String, uniqueID: MIDIUniqueID, midiReadProc: @escaping(MIDIReadProc), readProcRefCon: UnsafeMutableRawPointer?) -> SMDestinationEndpoint? {
        // If newUniqueID is 0, we'll use the unique ID that CoreMIDI generates for us

        var endpoint: SMDestinationEndpoint?
        let client = SMClient.sharedClient!

        // We are going to be making a lot of changes, so turn off external notifications
        // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
        do {
            let wasPostingExternalNotification = client.postsExternalSetupChangeNotification
            client.postsExternalSetupChangeNotification = false
            defer { client.postsExternalSetupChangeNotification = wasPostingExternalNotification }

            var newEndpointRef: MIDIEndpointRef = 0
            guard MIDIDestinationCreate(client.midiClient, name as CFString, midiReadProc, readProcRefCon, &newEndpointRef) == noErr else { return nil }

            // We want to get at the SMEndpoint immediately.
            // CoreMIDI will send us a notification that something was added, and then we will create an SMDestinationEndpoint.
            // However, the notification from CoreMIDI is posted in the run loop's main mode, and we don't want to wait for it to be run.
            // So we need to manually add the new endpoint, now.
            endpoint = immediatelyAddObject(withObjectRef: newEndpointRef) as? SMDestinationEndpoint
            if let endpoint = endpoint {
                endpoint.setOwnedByThisProcess()

                if uniqueID != 0 {
                    endpoint.setUniqueID(uniqueID)
                }
                if endpoint.uniqueID() == 0 {
                    // CoreMIDI didn't assign a unique ID to this endpoint, so we should generate one ourself
                    var success = false
                    while !success {
                        success = endpoint.setUniqueID(SMMIDIObject.generateNewUniqueID())
                    }
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

    public override class func midiObjectType() -> MIDIObjectType {
        MIDIObjectType.destination
    }

    public override class func midiObjectCount() -> Int {
        MIDIGetNumberOfDestinations()
    }

    public override class func midiObject(at index: Int) -> MIDIObjectRef {
        MIDIGetDestination(index)
    }

    // MARK: SMEndpoint required overrides

    public override class func endpointCount(forEntity entity: MIDIEntityRef) -> Int {
        MIDIEntityGetNumberOfDestinations(entity)
    }

    public override class func endpointRef(at index: Int, forEntity entity: MIDIEntityRef) -> MIDIEndpointRef {
        MIDIEntityGetDestination(entity, index)
    }

    // MARK: Sysex speed workaround
    //
    // The CoreMIDI client caches the last device that was given to MIDISendSysex(), along with its max sysex speed.
    // So when we change the speed, it doesn't notice and continues to use the old speed.
    // To fix this, we send a tiny sysex message to a different device.  Unfortunately we can't just use a NULL endpoint,
    // it has to be a real live endpoint.

    private static var cachedSysExSpeedWorkaroundEndpoint: SMDestinationEndpoint?
    static var creatingSysExSpeedWorkaroundEndpoint = false

    static var sysExSpeedWorkaroundEndpoint: SMDestinationEndpoint? {
        if cachedSysExSpeedWorkaroundEndpoint == nil {
            let client = SMClient.sharedClient!
            let wasPostingExternalNotification = client.postsExternalSetupChangeNotification

            // We are going to be making a lot of changes, so turn off external notifications
            // for a while (until we're done).
            do {
                client.postsExternalSetupChangeNotification = false
                defer { client.postsExternalSetupChangeNotification = wasPostingExternalNotification }

                // Also set a flag so we don't post object list notifications until this object has been fully set up
                // (and, most importantly, that we have assigned to cachedSysExSpeedWorkaroundEndpoint so
                // destinationEndpoints can do the filtering properly).
                creatingSysExSpeedWorkaroundEndpoint = true

                cachedSysExSpeedWorkaroundEndpoint = SMDestinationEndpoint.createVirtualDestinationEndpoint(name: "Workaround", uniqueID: 0, midiReadProc: doNothingMIDIReadProc, readProcRefCon: nil)

                cachedSysExSpeedWorkaroundEndpoint?.setInteger(1, forProperty: kMIDIPropertyPrivate)

                creatingSysExSpeedWorkaroundEndpoint = false

                // post internal notifications that we squelched earlier
                if let endpoint = cachedSysExSpeedWorkaroundEndpoint {
                    postListChangedNotification()
                    postObjectsAddedNotification(with: [endpoint])
                }
            }

            if wasPostingExternalNotification {
                // TODO If we still actually need this, clean up to have a userInfo to match
                NotificationCenter.default.post(name: .clientSetupChanged, object: SMClient.sharedClient)
            }
        }

        return cachedSysExSpeedWorkaroundEndpoint
    }

    public override class func postListChangedNotification() {
        if !creatingSysExSpeedWorkaroundEndpoint {
            super.postListChangedNotification()
        }
    }

    public override class func postObjectsAddedNotification(with objects: [Any]!) {
        if !creatingSysExSpeedWorkaroundEndpoint {
            super.postObjectsAddedNotification(with: objects)
        }
    }

}

private func doNothingMIDIReadProc(_ packetListPtr: UnsafePointer<MIDIPacketList>, _ readProcRefCon: UnsafeMutableRawPointer?, _ srcConnRefCon: UnsafeMutableRawPointer?) {
}
