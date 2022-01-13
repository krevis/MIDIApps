/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
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

    func entityGetNumberOfDestinations(_ entity: MIDIEntityRef) -> Int
    func entityGetDestination(_ entity: MIDIEntityRef, _ destIndex0: Int) -> MIDIEndpointRef

    func objectFindByUniqueID(_ inUniqueID: MIDIUniqueID, _ outObject: UnsafeMutablePointer<MIDIObjectRef>?, _ outObjectType: UnsafeMutablePointer<MIDIObjectType>?) -> OSStatus

    func sourceCreate(_ client: MIDIClientRef, _ name: CFString, _ outSrc: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus

    func destinationCreateWithBlock(_ client: MIDIClientRef, _ name: CFString, _ outDest: UnsafeMutablePointer<MIDIEndpointRef>, _ readBlock: @escaping MIDIReadBlock) -> OSStatus

    func endpointGetEntity(_ inEndpoint: MIDIEndpointRef, _ outEntity: UnsafeMutablePointer<MIDIEntityRef>?) -> OSStatus

    func entityGetDevice(_ inEntity: MIDIEntityRef, _ outDevice: UnsafeMutablePointer<MIDIDeviceRef>?) -> OSStatus

    func endpointDispose(_ endpt: MIDIEndpointRef) -> OSStatus

    func send(_ port: MIDIPortRef, _ dest: MIDIEndpointRef, _ pktlist: UnsafePointer<MIDIPacketList>) -> OSStatus

    func sendSysex(_ request: UnsafeMutablePointer<MIDISysexSendRequest>) -> OSStatus

    func inputPortCreateWithBlock(_ client: MIDIClientRef, _ portName: CFString, _ outPort: UnsafeMutablePointer<MIDIPortRef>, _ readBlock: @escaping MIDIReadBlock) -> OSStatus

    func outputPortCreate(_ client: MIDIClientRef, _ portName: CFString, _ outPort: UnsafeMutablePointer<MIDIPortRef>) -> OSStatus

    func portConnectSource(_ port: MIDIPortRef, _ source: MIDIEndpointRef, _ connRefCon: UnsafeMutableRawPointer?) -> OSStatus

    func portDisconnectSource(_ port: MIDIPortRef, _ source: MIDIEndpointRef) -> OSStatus

    func portDispose(_ port: MIDIPortRef) -> OSStatus

}

struct RealCoreMIDIInterface: CoreMIDIInterface {

    func clientCreateWithBlock(_ name: CFString, _ outClient: UnsafeMutablePointer<MIDIClientRef>, _ notifyBlock: MIDINotifyBlock?) -> OSStatus {
        return MIDIClientCreateWithBlock(name, outClient, notifyBlock)
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
