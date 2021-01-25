/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CoreMIDI

protocol CoreMIDIInterface {

    // Cover the CoreMIDI calls we will make.
    // This way we can pass a mock instance for testing

    func clientCreateWithBlock(_ name: CFString, _ outClient: UnsafeMutablePointer<MIDIClientRef>, _ notifyBlock: MIDINotifyBlock?) -> OSStatus

    func clientDispose(_ client: MIDIClientRef) -> OSStatus

    func objectGetStringProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ str: UnsafeMutablePointer<Unmanaged<CFString>?>) -> OSStatus

    func objectSetStringProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ str: CFString) -> OSStatus

    func objectGetIntegerProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ outValue: UnsafeMutablePointer<Int32>) -> OSStatus

    func objectSetIntegerProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ value: Int32) -> OSStatus

    func objectGetDataProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ outData: UnsafeMutablePointer<Unmanaged<CFData>?>) -> OSStatus

    func objectSetDataProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ data: CFData) -> OSStatus

    func objectRemoveProperty(_ obj: MIDIObjectRef, _ propertyID: CFString) -> OSStatus

    func getNumberOfDevices() -> Int
    func getDevice(_ deviceIndex0: Int) -> MIDIDeviceRef

    func getNumberOfExternalDevices() -> Int
    func getExternalDevice(_ deviceIndex0: Int) -> MIDIDeviceRef

    func getNumberOfSources() -> Int
    func getSource(_ sourceIndex0: Int) -> MIDIEndpointRef

    func getNumberOfDestinations() -> Int
    func getDestination(_ destIndex0: Int) -> MIDIEndpointRef

    func deviceGetNumberOfEntities(_ device: MIDIDeviceRef) -> Int
    func deviceGetEntity(_ device: MIDIDeviceRef, _ entityIndex0: Int) -> MIDIEntityRef

    func entityGetNumberOfSources(_ entity: MIDIEntityRef) -> Int
    func entityGetSource(_ entity: MIDIEntityRef, _ sourceIndex0: Int) -> MIDIEndpointRef

    func objectFindByUniqueID(_ inUniqueID: MIDIUniqueID, _ outObject: UnsafeMutablePointer<MIDIObjectRef>?, _ outObjectType: UnsafeMutablePointer<MIDIObjectType>?) -> OSStatus

    func sourceCreate(_ client: MIDIClientRef, _ name: CFString, _ outSrc: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus

}

struct RealCoreMIDIInterface: CoreMIDIInterface {

    func clientCreateWithBlock(_ name: CFString, _ outClient: UnsafeMutablePointer<MIDIClientRef>, _ notifyBlock: MIDINotifyBlock?) -> OSStatus {
        if #available(OSX 10.11, *) {
            return MIDIClientCreateWithBlock(name, outClient, notifyBlock)
        }
        else {
            // TODO
            fatalError()
        }
    }

    func clientDispose(_ client: MIDIClientRef) -> OSStatus {
        MIDIClientDispose(client)
    }

    func objectGetStringProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ str: UnsafeMutablePointer<Unmanaged<CFString>?>) -> OSStatus {
        MIDIObjectGetStringProperty(obj, propertyID, str)
    }

    func objectSetStringProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ str: CFString) -> OSStatus {
        MIDIObjectSetStringProperty(obj, propertyID, str)
    }

    func objectGetIntegerProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ outValue: UnsafeMutablePointer<Int32>) -> OSStatus {
        MIDIObjectGetIntegerProperty(obj, propertyID, outValue)
    }

    func objectSetIntegerProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ value: Int32) -> OSStatus {
        MIDIObjectSetIntegerProperty(obj, propertyID, value)
    }

    func objectGetDataProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ outData: UnsafeMutablePointer<Unmanaged<CFData>?>) -> OSStatus {
        MIDIObjectGetDataProperty(obj, propertyID, outData)
    }

    func objectSetDataProperty(_ obj: MIDIObjectRef, _ propertyID: CFString, _ data: CFData) -> OSStatus {
        MIDIObjectSetDataProperty(obj, propertyID, data)
    }

    func objectRemoveProperty(_ obj: MIDIObjectRef, _ propertyID: CFString) -> OSStatus {
        MIDIObjectRemoveProperty(obj, propertyID)
    }

    func getNumberOfDevices() -> Int {
        MIDIGetNumberOfDevices()
    }

    func getDevice(_ deviceIndex0: Int) -> MIDIDeviceRef {
        MIDIGetDevice(deviceIndex0)
    }

    func getNumberOfExternalDevices() -> Int {
        MIDIGetNumberOfExternalDevices()
    }

    func getExternalDevice(_ deviceIndex0: Int) -> MIDIDeviceRef {
        MIDIGetExternalDevice(deviceIndex0)
    }

    func getNumberOfSources() -> Int {
        MIDIGetNumberOfSources()
    }

    func getSource(_ sourceIndex0: Int) -> MIDIEndpointRef {
        MIDIGetSource(sourceIndex0)
    }

    func getNumberOfDestinations() -> Int {
        MIDIGetNumberOfDestinations()
    }

    func getDestination(_ destIndex0: Int) -> MIDIEndpointRef {
        MIDIGetDestination(destIndex0)
    }

    func deviceGetNumberOfEntities(_ device: MIDIDeviceRef) -> Int {
        MIDIDeviceGetNumberOfEntities(device)
    }

    func deviceGetEntity(_ device: MIDIDeviceRef, _ entityIndex0: Int) -> MIDIEntityRef {
        MIDIDeviceGetEntity(device, entityIndex0)
    }

    func entityGetNumberOfSources(_ entity: MIDIEntityRef) -> Int {
        MIDIEntityGetNumberOfSources(entity)
    }

    func entityGetSource(_ entity: MIDIEntityRef, _ sourceIndex0: Int) -> MIDIEndpointRef {
        MIDIEntityGetSource(entity, sourceIndex0)
    }

    func objectFindByUniqueID(_ inUniqueID: MIDIUniqueID, _ outObject: UnsafeMutablePointer<MIDIObjectRef>?, _ outObjectType: UnsafeMutablePointer<MIDIObjectType>?) -> OSStatus {
        MIDIObjectFindByUniqueID(inUniqueID, outObject, outObjectType)
    }

    func sourceCreate(_ client: MIDIClientRef, _ name: CFString, _ outSrc: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus {
        MIDISourceCreate(client, name, outSrc)
    }

}
