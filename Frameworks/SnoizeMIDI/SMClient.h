//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMClient : OFObject
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
- (void *)coreMIDIFunctionNamed:(NSString *)functionName;
- (UInt32)coreMIDIFrameworkVersion;

- (BOOL)postsObjectAddedAndRemovedNotifications;
- (BOOL)postsObjectPropertyChangedNotifications;

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
