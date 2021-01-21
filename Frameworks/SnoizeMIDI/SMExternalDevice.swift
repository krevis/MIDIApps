/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CoreMIDI

@objc public class SMExternalDevice: SMMIDIObject {

    @objc public class var externalDevices: [SMExternalDevice] {
        (allObjectsInOrder as? [SMExternalDevice]) ?? []
    }

    @objc public class func externalDevice(uniqueID: MIDIUniqueID) -> SMExternalDevice? {
        findObject(uniqueID: uniqueID)
        // TODO This is unused, see if we really need it
    }

    @objc public class func externalDevice(deviceRef: MIDIDeviceRef) -> SMExternalDevice? {
        findObject(objectRef: deviceRef)
    }

    // MARK: New SMExternalDevice API

    public var deviceRef: MIDIDeviceRef {
        objectRef
        // TODO This is unused, see if we really need it
    }

    public var manufacturerName: String? {
        string(forProperty: kMIDIPropertyManufacturer)
        // TODO This is unused, see if we really need it
    }

    public var modelName: String? {
        string(forProperty: kMIDIPropertyModel)
        // TODO This is unused, see if we really need it
    }

    public var pathToImageFile: String? {
        string(forProperty: kMIDIPropertyImage)
        // TODO This is unused, see if we really need it
    }

    // MARK: SMMIDIObject subclass

    public class override var midiObjectType: MIDIObjectType {
        MIDIObjectType.externalDevice
    }

    public class override var midiObjectCount: Int {
        MIDIGetNumberOfExternalDevices()
    }

    public class override func midiObject(at index: Int) -> MIDIObjectRef {
        MIDIGetExternalDevice(index)
    }

    public override var maxSysExSpeed: Int {
        didSet {
            // Also set the speed on this device's source endpoints (which we get to via its entities).
            // This is how MIDISendSysex() determines what speed to use, surprisingly.

            for entityIndex in 0 ..< MIDIDeviceGetNumberOfEntities(deviceRef) {
                let entityRef = MIDIDeviceGetEntity(deviceRef, entityIndex)
                for sourceIndex in 0 ..< MIDIEntityGetNumberOfSources(entityRef) {
                    let sourceEndpointRef = MIDIEntityGetSource(entityRef, sourceIndex)
                    MIDIObjectSetIntegerProperty(sourceEndpointRef, kMIDIPropertyMaxSysExSpeed, Int32(maxSysExSpeed))
                    // ignore errors, nothing we can do anyway
                }
            }
        }
    }

}
