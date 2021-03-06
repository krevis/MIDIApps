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

    func clientCreate(_ name: CFString, _ notifyProc: MIDINotifyProc?, _ notifyRefCon: UnsafeMutableRawPointer?, _ outClient: UnsafeMutablePointer<MIDIClientRef>) -> OSStatus

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

    func entityGetNumberOfDestinations(_ entity: MIDIEntityRef) -> Int
    func entityGetDestination(_ entity: MIDIEntityRef, _ destIndex0: Int) -> MIDIEndpointRef

    func objectFindByUniqueID(_ inUniqueID: MIDIUniqueID, _ outObject: UnsafeMutablePointer<MIDIObjectRef>?, _ outObjectType: UnsafeMutablePointer<MIDIObjectType>?) -> OSStatus

    func sourceCreate(_ client: MIDIClientRef, _ name: CFString, _ outSrc: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus

    func destinationCreate(_ client: MIDIClientRef, _ name: CFString, _ readProc: @escaping MIDIReadProc, _ refCon: UnsafeMutableRawPointer?, _ outDest: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus

    @available(macOS 10.11, *)
    func destinationCreateWithBlock(_ client: MIDIClientRef, _ name: CFString, _ outDest: UnsafeMutablePointer<MIDIEndpointRef>, _ readBlock: @escaping MIDIReadBlock) -> OSStatus

    func endpointGetEntity(_ inEndpoint: MIDIEndpointRef, _ outEntity: UnsafeMutablePointer<MIDIEntityRef>?) -> OSStatus

    func entityGetDevice(_ inEntity: MIDIEntityRef, _ outDevice: UnsafeMutablePointer<MIDIDeviceRef>?) -> OSStatus

    func endpointDispose(_ endpt: MIDIEndpointRef) -> OSStatus

    func send(_ port: MIDIPortRef, _ dest: MIDIEndpointRef, _ pktlist: UnsafePointer<MIDIPacketList>) -> OSStatus

    func sendSysex(_ request: UnsafeMutablePointer<MIDISysexSendRequest>) -> OSStatus

    func inputPortCreate(_ client: MIDIClientRef, _ portName: CFString, _ readProc: @escaping MIDIReadProc, _ refCon: UnsafeMutableRawPointer?, _ outPort: UnsafeMutablePointer<MIDIPortRef>) -> OSStatus

    @available(macOS 10.11, *)
    func inputPortCreateWithBlock(_ client: MIDIClientRef, _ portName: CFString, _ outPort: UnsafeMutablePointer<MIDIPortRef>, _ readBlock: @escaping MIDIReadBlock) -> OSStatus

    func outputPortCreate(_ client: MIDIClientRef, _ portName: CFString, _ outPort: UnsafeMutablePointer<MIDIPortRef>) -> OSStatus

    func portConnectSource(_ port: MIDIPortRef, _ source: MIDIEndpointRef, _ connRefCon: UnsafeMutableRawPointer?) -> OSStatus

    func portDisconnectSource(_ port: MIDIPortRef, _ source: MIDIEndpointRef) -> OSStatus

    func portDispose(_ port: MIDIPortRef) -> OSStatus

}

struct RealCoreMIDIInterface: CoreMIDIInterface {

    func clientCreateWithBlock(_ name: CFString, _ outClient: UnsafeMutablePointer<MIDIClientRef>, _ notifyBlock: MIDINotifyBlock?) -> OSStatus {
        if #available(OSX 10.11, iOS 9.0, *) {
            return MIDIClientCreateWithBlock(name, outClient, notifyBlock)
        }
        else {
            fatalError()
        }
    }

    func clientCreate(_ name: CFString, _ notifyProc: MIDINotifyProc?, _ notifyRefCon: UnsafeMutableRawPointer?, _ outClient: UnsafeMutablePointer<MIDIClientRef>) -> OSStatus {
        MIDIClientCreate(name, notifyProc, notifyRefCon, outClient)
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

    func entityGetNumberOfDestinations(_ entity: MIDIEntityRef) -> Int {
        MIDIEntityGetNumberOfDestinations(entity)
    }

    func entityGetDestination(_ entity: MIDIEntityRef, _ destIndex0: Int) -> MIDIEndpointRef {
        MIDIEntityGetDestination(entity, destIndex0)
    }

    func objectFindByUniqueID(_ inUniqueID: MIDIUniqueID, _ outObject: UnsafeMutablePointer<MIDIObjectRef>?, _ outObjectType: UnsafeMutablePointer<MIDIObjectType>?) -> OSStatus {
        MIDIObjectFindByUniqueID(inUniqueID, outObject, outObjectType)
    }

    func sourceCreate(_ client: MIDIClientRef, _ name: CFString, _ outSrc: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus {
        MIDISourceCreate(client, name, outSrc)
    }

    func destinationCreate(_ client: MIDIClientRef, _ name: CFString, _ readProc: @escaping MIDIReadProc, _ refCon: UnsafeMutableRawPointer?, _ outDest: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus {
        MIDIDestinationCreate(client, name, readProc, refCon, outDest)
    }

    @available(macOS 10.11, *)
    func destinationCreateWithBlock(_ client: MIDIClientRef, _ name: CFString, _ outDest: UnsafeMutablePointer<MIDIEndpointRef>, _ readBlock: @escaping MIDIReadBlock) -> OSStatus {
        MIDIDestinationCreateWithBlock(client, name, outDest, readBlock)
    }

    func endpointGetEntity(_ inEndpoint: MIDIEndpointRef, _ outEntity: UnsafeMutablePointer<MIDIEntityRef>?) -> OSStatus {
        MIDIEndpointGetEntity(inEndpoint, outEntity)
    }

    func entityGetDevice(_ inEntity: MIDIEntityRef, _ outDevice: UnsafeMutablePointer<MIDIDeviceRef>?) -> OSStatus {
        MIDIEntityGetDevice(inEntity, outDevice)
    }

    func endpointDispose(_ endpt: MIDIEndpointRef) -> OSStatus {
        MIDIEndpointDispose(endpt)
    }

    func send(_ port: MIDIPortRef, _ dest: MIDIEndpointRef, _ pktlist: UnsafePointer<MIDIPacketList>) -> OSStatus {
        MIDISend(port, dest, pktlist)
    }

    func sendSysex(_ request: UnsafeMutablePointer<MIDISysexSendRequest>) -> OSStatus {
        MIDISendSysex(request)
    }

    func inputPortCreate(_ client: MIDIClientRef, _ portName: CFString, _ readProc: @escaping MIDIReadProc, _ refCon: UnsafeMutableRawPointer?, _ outPort: UnsafeMutablePointer<MIDIPortRef>) -> OSStatus {
        MIDIInputPortCreate(client, portName, readProc, refCon, outPort)
    }

    @available(macOS 10.11, *)
    public func inputPortCreateWithBlock(_ client: MIDIClientRef, _ portName: CFString, _ outPort: UnsafeMutablePointer<MIDIPortRef>, _ readBlock: @escaping MIDIReadBlock) -> OSStatus {
        MIDIInputPortCreateWithBlock(client, portName, outPort, readBlock)
    }

    func outputPortCreate(_ client: MIDIClientRef, _ portName: CFString, _ outPort: UnsafeMutablePointer<MIDIPortRef>) -> OSStatus {
        MIDIOutputPortCreate(client, portName, outPort)
    }

    func portConnectSource(_ port: MIDIPortRef, _ source: MIDIEndpointRef, _ connRefCon: UnsafeMutableRawPointer?) -> OSStatus {
        MIDIPortConnectSource(port, source, connRefCon)
    }

    func portDisconnectSource(_ port: MIDIPortRef, _ source: MIDIEndpointRef) -> OSStatus {
        MIDIPortDisconnectSource(port, source)
    }

    public func portDispose(_ port: MIDIPortRef) -> OSStatus {
        MIDIPortDispose(port)
    }

}
