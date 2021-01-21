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

@objc public class SMDevice: SMMIDIObject {

    @objc public class var devices: [SMDevice] {
        (allObjectsInOrder as? [SMDevice]) ?? []
    }

    @objc public class func device(uniqueID: MIDIUniqueID) -> SMDevice? {
        findObject(uniqueID: uniqueID) as? SMDevice
        // TODO This is unused, see if we really need it
    }

    @objc public class func device(deviceRef: MIDIDeviceRef) -> SMDevice? {
        findObject(objectRef: deviceRef) as? SMDevice
    }

    // MARK: New SMDevice API

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
        MIDIObjectType.device
    }

    public class override var midiObjectCount: Int {
        MIDIGetNumberOfDevices()
    }

    public class override func midiObject(at index: Int) -> MIDIObjectRef {
        MIDIGetDevice(index)
    }

    public override func propertyDidChange(_ property: CFString) {
        if property == kMIDIPropertyOffline {
            // This device just went offline or online. We need to refresh its endpoints.
            // (If it went online, we didn't previously have its endpoints in our list.)

            // TODO This is an overly blunt approach.
            SMSourceEndpoint.refreshAllObjects()
            SMDestinationEndpoint.refreshAllObjects()
        }

        super.propertyDidChange(property)
    }

}
