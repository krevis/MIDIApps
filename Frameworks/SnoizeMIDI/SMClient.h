/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMDestinationEndpoint;

@interface SMClient : NSObject
{
    MIDIClientRef midiClient;
    NSString *name;
    BOOL postsExternalSetupChangeNotification;
    BOOL isHandlingSetupChange;
    CFBundleRef coreMIDIFrameworkBundle;
    NSMutableDictionary *coreMIDIPropertyNameDictionary;
}

+ (SMClient *)sharedClient;

- (MIDIClientRef)midiClient;
- (NSString *)name;

- (BOOL)postsExternalSetupChangeNotification;
- (void)setPostsExternalSetupChangeNotification:(BOOL)value;

- (BOOL)isHandlingSetupChange;

- (CFStringRef)coreMIDIPropertyNameConstantNamed:(NSString *)name;
- (UInt32)coreMIDIFrameworkVersion;

- (BOOL)postsObjectAddedAndRemovedNotifications;
- (BOOL)postsObjectPropertyChangedNotifications;
- (BOOL)coreMIDIUsesWrongRunLoop;
- (BOOL)coreMIDICanFindObjectByUniqueID;
- (BOOL)coreMIDICanGetDeviceFromEntity;
- (BOOL)doesSendSysExRespectExternalDeviceSpeed;

- (void)forceCoreMIDIToUseNewSysExSpeed;

@end

// Notifications

extern NSString *SMClientCreatedInternalNotification;
    // Sent when the client is created. Meant only for use by SnoizeMIDI classes. No userInfo.

// Notifications sent as a result of CoreMIDI notifications

    // The default "something changed" kMIDIMsgSetupChanged notification from CoreMIDI:
extern NSString *SMClientSetupChangedInternalNotification;
    // Meant only for use by SnoizeMIDI classes. No userInfo.
extern NSString *SMClientSetupChangedNotification;
    // No userInfo

    // An object was added:
extern NSString *SMClientObjectAddedNotification;
    // userInfo contains:
    //   SMClientObjectAddedOrRemovedParent	NSValue (MIDIObjectRef as pointer)
    //   SMClientObjectAddedOrRemovedParentType	NSNumber (MIDIObjectType as SInt32)
    //   SMClientObjectAddedOrRemovedChild		NSValue (MIDIObjectRef as pointer)
    //   SMClientObjectAddedOrRemovedChildType	NSNumber (MIDIObjectType as SInt32)
extern NSString *SMClientObjectAddedOrRemovedParent;
extern NSString *SMClientObjectAddedOrRemovedParentType;
extern NSString *SMClientObjectAddedOrRemovedChild;
extern NSString *SMClientObjectAddedOrRemovedChildType;

    // An object was removed:
extern NSString *SMClientObjectRemovedNotification;
    // userInfo is the same as for SMClientObjectAddedNotification above

    // A property of an object changed:
extern NSString *SMClientObjectPropertyChangedNotification;
    // userInfo contains:
    //   SMClientObjectPropertyChangedObject		NSValue (MIDIObjectRef as pointer)
    //   SMClientObjectPropertyChangedType		NSNumber (MIDIObjectType as SInt32)
    //   SMClientObjectPropertyChangedName		NSString
extern NSString *SMClientObjectPropertyChangedObject;
extern NSString *SMClientObjectPropertyChangedType;
extern NSString *SMClientObjectPropertyChangedName;

    // A MIDI Thru connection changed:
extern NSString *SMClientThruConnectionsChangedNotification;
    // userInfo is same as for SMClientMIDINotification (above).

    // An owner of a serial port changed:
extern NSString *SMClientSerialPortOwnerChangedNotification;
    // userInfo is same as for SMClientMIDINotification (above).

    // Sent for unknown notifications from CoreMIDI:
extern NSString *SMClientMIDINotification;
    // userInfo contains these keys and values:
    //	SMClientMIDINotificationStruct	NSValue (a pointer to a struct MIDINotification)
extern NSString *SMClientMIDINotificationStruct;
