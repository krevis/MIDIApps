//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SMInputStreamSource.h>
#import <SnoizeMIDI/SMMIDIObject.h>

@class SMDevice;


@interface SMEndpoint : SMMIDIObject <SMInputStreamSource>
{
    MIDIDeviceRef deviceRef;
    struct {
        unsigned int hasLookedForDevice:1;
        unsigned int hasCachedManufacturerName:1;
        unsigned int hasCachedModelName:1;
    } endpointFlags;

    NSString *cachedManufacturerName;
    NSString *cachedModelName;
}

// Implemented only on subclasses of SMEndpoint
+ (ItemCount)endpointCountForEntity:(MIDIEntityRef)entity;
+ (MIDIEndpointRef)endpointRefAtIndex:(ItemCount)index forEntity:(MIDIEntityRef)entity;

- (MIDIEndpointRef)endpointRef;

- (BOOL)isVirtual;
- (BOOL)isOwnedByThisProcess;
- (void)setIsOwnedByThisProcess;
- (void)remove;	// only works on virtual endpoints owned by this process
    
- (NSString *)manufacturerName;
- (void)setManufacturerName:(NSString *)value;

- (NSString *)modelName;
- (void)setModelName:(NSString *)value;

- (NSString *)uniqueName;
    // If all endpoints of the same kind (source or destination) have unique names,
    // returns -name. Otherwise, returns -longName.

- (NSString *)alwaysUniqueName;
    // If all endpoints of the same kind (source or destination) have ALWAYS had unique names,
    // returns -name. Otherwise, returns -longName.

- (NSString *)longName;
    // Returns "<device name> <endpoint name>". If there is no device for this endpoint
    // (that is, if it's virtual) return "<model name> <endpoint name>".

- (SInt32)advanceScheduleTime;
- (void)setAdvanceScheduleTime:(SInt32)newValue;
    // Value is in milliseconds

- (BOOL)needsSysExWorkaround;
    // Returns YES if the endpoint is provided by the broken MIDIMAN driver, which can't send more than 3 bytes of sysex at once

- (NSString *)pathToImageFile;
    // Returns a POSIX path to the image for this endpoint's device, or nil if there is no image.

- (NSArray *)uniqueIDsOfConnectedThings;
    // may be external devices, endpoints, or who knows what
- (NSArray *)connectedExternalDevices;

- (SMDevice *)device;
    // may return nil if this endpoint is virtual

// SMInputStreamSource protocol
- (NSString *)inputStreamSourceName;
- (NSNumber *)inputStreamSourceUniqueID;
- (NSArray *)inputStreamSourceExternalDeviceNames;

@end


@interface SMSourceEndpoint : SMEndpoint
{
}

+ (NSArray *)sourceEndpoints;
+ (SMSourceEndpoint *)sourceEndpointWithUniqueID:(MIDIUniqueID)uniqueID;
+ (SMSourceEndpoint *)sourceEndpointWithName:(NSString *)name;
+ (SMSourceEndpoint *)sourceEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;

+ (SMSourceEndpoint *)createVirtualSourceEndpointWithName:(NSString *)newName uniqueID:(MIDIUniqueID)newUniqueID;
    // If newUniqueID is 0, we'll use the unique ID that CoreMIDI generates for us

@end


@interface SMDestinationEndpoint : SMEndpoint
{
}

+ (NSArray *)destinationEndpoints;
+ (SMDestinationEndpoint *)destinationEndpointWithUniqueID:(MIDIUniqueID)uniqueID;
+ (SMDestinationEndpoint *)destinationEndpointWithName:(NSString *)aName;
+ (SMDestinationEndpoint *)destinationEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;

+ (SMDestinationEndpoint *)createVirtualDestinationEndpointWithName:(NSString *)endpointName readProc:(MIDIReadProc)readProc readProcRefCon:(void *)readProcRefCon uniqueID:(MIDIUniqueID)newUniqueID;
    // If newUniqueID is 0, we'll use the unique ID that CoreMIDI generates for us

+ (void)flushOutputForAllDestinationEndpoints;
- (void)flushOutput;

@end


// MIDI property keys

extern NSString *SMEndpointPropertyOwnerPID;
    // We set this on the virtual endpoints that we create, so we can query them to see if they're ours.
