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
        (allObjectsInOrder() as? [SMSourceEndpoint]) ?? []
    }

    @objc public class func findSourceEndpoint(uniqueID: MIDIUniqueID) -> SMSourceEndpoint? {
        find(withUniqueID: uniqueID) as? SMSourceEndpoint
        // TODO Better name
    }

    @objc public class func findSourceEndpoint(name: String) -> SMSourceEndpoint? {
        find(withName: name) as? SMSourceEndpoint
        // TODO Better name
    }

    @objc public class func findSourceEndpoint(endpointRef: MIDIEndpointRef) -> SMSourceEndpoint? {
        findObject(withObjectRef: endpointRef) as? SMSourceEndpoint
        // TODO This is unused, see if we really need it
    }

    public class func createVirtualSourceEndpoint(name: String, uniqueID: MIDIUniqueID) -> SMSourceEndpoint? {
        // If newUniqueID is 0, we'll use the unique ID that CoreMIDI generates for us
        // TODO

        /*
         SMClient *client = [SMClient sharedClient];
         OSStatus status;
         MIDIEndpointRef newEndpointRef;
         BOOL wasPostingExternalNotification;
         SMSourceEndpoint *endpoint;

         // We are going to be making a lot of changes, so turn off external notifications
         // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
         wasPostingExternalNotification = [client postsExternalSetupChangeNotification];
         [client setPostsExternalSetupChangeNotification:NO];

         status = MIDISourceCreate([client midiClient], (CFStringRef)newName, &newEndpointRef);
         if (status)
             return nil;

         // We want to get at the SMEndpoint immediately.
         // CoreMIDI will send us a notification that something was added, and then we will create an SMSourceEndpoint.
         // However, the notification from CoreMIDI is posted in the run loop's main mode, and we don't want to wait for it to be run.
         // So we need to manually add the new endpoint, now.
         endpoint = (SMSourceEndpoint *)[self immediatelyAddObjectWithObjectRef:newEndpointRef];
         if (!endpoint) {
             NSLog(@"%@ couldn't find its virtual endpoint after it was created", NSStringFromClass(self));
             return nil;
         }

         [endpoint setIsOwnedByThisProcess];

         if (newUniqueID != 0)
             [endpoint setUniqueID:newUniqueID];
         if ([endpoint uniqueID] == 0) {
             // CoreMIDI didn't assign a unique ID to this endpoint, so we should generate one ourself
             BOOL success = NO;

             while (!success)
                 success = [endpoint setUniqueID:[SMMIDIObject generateNewUniqueID]];
         }

         [endpoint setManufacturerName:@"Snoize"];

         // Do this before the last modification, so one setup change notification will still happen
         [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

         [endpoint setModelName:[client name]];

         return endpoint;

         */

        return nil
    }

    // MARK: SMMIDIObject required overrides

    public override class func midiObjectType() -> MIDIObjectType {
        MIDIObjectType.source
    }

    public override class func midiObjectCount() -> Int {
        MIDIGetNumberOfSources()
    }

    public override class func midiObject(at index: Int) -> MIDIObjectRef {
        MIDIGetSource(index)
    }

    // MARK: SMEndpoint required overrides

    private static var areNamesUnique = true
    private static var haveNamesAlwaysBeenUnique = true

    public override class func doEndpointsHaveUniqueNames() -> Bool {
        areNamesUnique
    }

    public override class func haveEndpointsAlwaysHadUniqueNames() -> Bool {
        haveNamesAlwaysBeenUnique
    }

    public override class func setAreNamesUnique(_ areUnique: Bool) {
        areNamesUnique = areUnique
        haveNamesAlwaysBeenUnique = haveNamesAlwaysBeenUnique && areUnique
    }

    public override class func endpointCount(forEntity entity: MIDIEntityRef) -> Int {
        MIDIEntityGetNumberOfSources(entity)
    }

    public override class func endpointRef(at index: Int, forEntity entity: MIDIEntityRef) -> MIDIEndpointRef {
        MIDIEntityGetSource(entity, index)
    }

}
