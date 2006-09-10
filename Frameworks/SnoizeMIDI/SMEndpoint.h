/*
 Copyright (c) 2001-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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

+ (SMDestinationEndpoint*) sysExSpeedWorkaroundDestinationEndpoint;

@end


// MIDI property keys

extern NSString *SMEndpointPropertyOwnerPID;
    // We set this on the virtual endpoints that we create, so we can query them to see if they're ours.
