/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMIDIObject.h"
#import "SMSystemExclusiveMessage.h"
#import "SMSysExSendRequest.h"


@interface SMClient (Private)

- (NSString *)processName;

static void getMIDINotification(const MIDINotification *message, void *refCon);

- (void)midiSetupChanged;
- (void)midiObjectAddedOrRemoved:(const MIDIObjectAddRemoveNotification *)message;
- (void)midiObjectPropertyChanged:(const MIDIObjectPropertyChangeNotification *)message;
- (void)midiThruConnectionsChanged:(const MIDINotification *)message;
- (void)serialPortOwnerChanged:(const MIDINotification *)message;
- (void)broadcastUnknownMIDINotification:(const MIDINotification *)message;
- (void)broadcastGenericMIDINotification:(const MIDINotification *)message withName:(NSString *)notificationName;

@end


@implementation SMClient

NSString *SMClientCreatedInternalNotification = @"SMClientCreatedInternalNotification";
NSString *SMClientSetupChangedInternalNotification = @"SMClientSetupChangedInternalNotification";
NSString *SMClientSetupChangedNotification = @"SMClientSetupChangedNotification";
NSString *SMClientObjectAddedNotification = @"SMClientObjectAddedNotification";
NSString *SMClientObjectAddedOrRemovedParent = @"SMClientObjectAddedOrRemovedParent";
NSString *SMClientObjectAddedOrRemovedParentType = @"SMClientObjectAddedOrRemovedParentType";
NSString *SMClientObjectAddedOrRemovedChild = @"SMClientObjectAddedOrRemovedChild";
NSString *SMClientObjectAddedOrRemovedChildType = @"SMClientObjectAddedOrRemovedChildType";
NSString *SMClientObjectRemovedNotification = @"SMClientObjectRemovedNotification";
NSString *SMClientObjectPropertyChangedNotification = @"SMClientObjectPropertyChangedNotification";
NSString *SMClientObjectPropertyChangedObject = @"SMClientObjectPropertyChangedObject";
NSString *SMClientObjectPropertyChangedType = @"SMClientObjectPropertyChangedType";
NSString *SMClientObjectPropertyChangedName = @"SMClientObjectPropertyChangedName";
NSString *SMClientMIDINotification = @"SMClientMIDINotification";
NSString *SMClientMIDINotificationStruct = @"SMClientMIDINotificationStruct";
NSString *SMClientThruConnectionsChangedNotification =  @"SMClientThruConnectionsChangedNotification";
NSString *SMClientSerialPortOwnerChangedNotification = @"SMClientSerialPortOwnerChangedNotification";


static SMClient *sharedClient = nil;

+ (SMClient *)sharedClient;
{
    if (!sharedClient) {
        sharedClient = [[self alloc] init];
        
        // make sure SMMIDIObject is listening for the notification below
        [SMMIDIObject class];   // provokes +[SMMIDIObject initialize] if necessary
        
        if (sharedClient)
            [[NSNotificationCenter defaultCenter] postNotificationName:SMClientCreatedInternalNotification object:sharedClient];
    }

    return sharedClient;
}

+ (void)disposeSharedClient
{
    [sharedClient release];
    sharedClient = nil;
}

- (id)init;
{
    OSStatus status;

    if (!(self = [super init]))
        return nil;

    // Don't let anyone create more than one client
    if (sharedClient) {
        [self release];
        return nil;
    }

    name = [[self processName] retain];
    postsExternalSetupChangeNotification = YES;
    isHandlingSetupChange = NO;
    coreMIDIFrameworkBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.audio.midi.CoreMIDI"));
    coreMIDIPropertyNameDictionary = [[NSMutableDictionary alloc] init];
    
    status = MIDIClientCreate((CFStringRef)name, getMIDINotification, self, &midiClient);
    if (status != noErr) {
        NSLog(@"Couldn't create a MIDI client (error %ld)", (long)status);
        [self release];
        return nil;
    }

    return self;
}

- (void)dealloc
{
    if (midiClient)
        MIDIClientDispose(midiClient);

    [name release];
    name = nil;
    [coreMIDIPropertyNameDictionary release];
    coreMIDIPropertyNameDictionary = nil;

    [super dealloc];
}

- (MIDIClientRef)midiClient;
{
    return midiClient;
}

- (NSString *)name;
{
    return name;
}

- (BOOL)postsExternalSetupChangeNotification;
{
    return postsExternalSetupChangeNotification;
}

- (void)setPostsExternalSetupChangeNotification:(BOOL)value;
{
    postsExternalSetupChangeNotification = value;
}

- (BOOL)isHandlingSetupChange;
{
    return isHandlingSetupChange;    
}

- (CFStringRef)coreMIDIPropertyNameConstantNamed:(NSString *)constantName;
{
    // This method is used to look up CoreMIDI property names which may or may not exist.
    // (For example, kMIDIPropertyImage, which is present in 10.2 but not 10.1.)
    // If we used the value kMIDIPropertyImage directly, we could no longer run on 10.1 since dyld
    // would be unable to find that symbol. So we look it up at runtime instead.
    // We keep these values cached in a dictionary so we don't do a lot of potentially slow lookups
    // through CFBundle.
    
    id coreMIDIPropertyNameConstant;

    // Look for this name in the cache
    coreMIDIPropertyNameConstant = [coreMIDIPropertyNameDictionary objectForKey:constantName];

    if (!coreMIDIPropertyNameConstant) {
        // Try looking up a symbol with this name in the CoreMIDI bundle.
        if (coreMIDIFrameworkBundle) {
            CFStringRef *propertyNamePtr;

            propertyNamePtr = CFBundleGetDataPointerForName(coreMIDIFrameworkBundle, (CFStringRef)constantName);
            if (propertyNamePtr)
                coreMIDIPropertyNameConstant = *(id *)propertyNamePtr;
        }

        // If we didn't find it, put an NSNull in the dict instead (so we don't try again to look it up later)
        if (!coreMIDIPropertyNameConstant)
            coreMIDIPropertyNameConstant = [NSNull null];
        [coreMIDIPropertyNameDictionary setObject:coreMIDIPropertyNameConstant forKey:name];
    }

    if (coreMIDIPropertyNameConstant == [NSNull null])
        return NULL;
    else
        return (CFStringRef)coreMIDIPropertyNameConstant;
}

- (UInt32)coreMIDIFrameworkVersion;
{
    if (coreMIDIFrameworkBundle)
        return CFBundleGetVersionNumber(coreMIDIFrameworkBundle);
    else
        return 0;
}

// NOTE: CoreMIDI.framework has CFBundleVersion "20" as of 10.2. This translates to 0x20008000.
const UInt32 kCoreMIDIFrameworkVersionIn10_2 = 0x20008000;
// CFBundleVersion is "26" as of 10.3 (WWDC build 7A179), which is 0x26008000.
const UInt32 kCoreMIDIFrameworkVersionIn10_3 = 0x26008000;	// TODO find out what this in in 10.3 GM

- (BOOL)postsObjectAddedAndRemovedNotifications;
{
    // CoreMIDI in 10.2 posts specific notifications when objects are added and removed.
    return [self coreMIDIFrameworkVersion] >= kCoreMIDIFrameworkVersionIn10_2;
}

- (BOOL)postsObjectPropertyChangedNotifications;
{
    // CoreMIDI in 10.2 posts a specific notification when an object's property changes.
    return [self coreMIDIFrameworkVersion] >= kCoreMIDIFrameworkVersionIn10_2;
}

- (BOOL)coreMIDIUsesWrongRunLoop;
{
    // Under 10.1 CoreMIDI calls can run the thread's run loop in the default run loop mode,
    // which causes no end of mischief.  Fortunately this was fixed in 10.2 to use a private mode.
    return [self coreMIDIFrameworkVersion] < kCoreMIDIFrameworkVersionIn10_2;    
}

- (BOOL)coreMIDICanFindObjectByUniqueID;
{
    return [self coreMIDIFrameworkVersion] >= kCoreMIDIFrameworkVersionIn10_2;        
}

- (BOOL)coreMIDICanGetDeviceFromEntity;
{
    return [self coreMIDIFrameworkVersion] >= kCoreMIDIFrameworkVersionIn10_2;        
}

- (BOOL)doesSendSysExRespectExternalDeviceSpeed
{
    return [self coreMIDIFrameworkVersion] >= kCoreMIDIFrameworkVersionIn10_3;
}

- (void)forceCoreMIDIToUseNewSysExSpeed
{
    // The CoreMIDI client caches the last device that was given to MIDISendSysex(), along with its max sysex speed.
    // So when we change the speed, it doesn't notice and continues to use the old speed.
    // To fix this, we send a tiny sysex message to a different device.  Unfortunately we can't just use a NULL endpoint,
    // it has to be a real live endpoint.    
    
    NS_DURING {
        SMDestinationEndpoint* endpoint = [SMDestinationEndpoint sysExSpeedWorkaroundDestinationEndpoint];           
        SMSystemExclusiveMessage* message = [SMSystemExclusiveMessage systemExclusiveMessageWithTimeStamp: 0 data: [NSData data]];
        [[SMSysExSendRequest sysExSendRequestWithMessage: message endpoint: endpoint] send];
    } NS_HANDLER {
        // don't care
    } NS_ENDHANDLER;    
}

@end


@implementation SMClient (Private)

- (NSString *)processName;
{
    NSString *processName;

    processName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleNameKey];
    if (!processName)
        processName = [[NSProcessInfo processInfo] processName];

    return processName;
}        

static void getMIDINotification(const MIDINotification *message, void *refCon)
{
    SMClient *client = (SMClient *)refCon;

    switch (message->messageID) {
        case kMIDIMsgSetupChanged:	// The only notification in 10.1 and earlier
#if DEBUG
            NSLog(@"setup changed");
#endif
            [client midiSetupChanged];
            break;

        case kMIDIMsgObjectAdded:	// Added in 10.2
#if DEBUG
            NSLog(@"object added");
#endif
            [client midiObjectAddedOrRemoved:(const MIDIObjectAddRemoveNotification *)message];
            break;

        case kMIDIMsgObjectRemoved:	// Added in 10.2
#if DEBUG
            NSLog(@"object removed");
#endif
            [client midiObjectAddedOrRemoved:(const MIDIObjectAddRemoveNotification *)message];
            break;

        case kMIDIMsgPropertyChanged:	// Added in 10.2
#if DEBUG
            NSLog(@"property changed");
#endif
            [client midiObjectPropertyChanged:(const MIDIObjectPropertyChangeNotification *)message];
            break;

        case kMIDIMsgThruConnectionsChanged:	// Added in 10.2
#if DEBUG
            NSLog(@"thru connections changed");
#endif
            [client midiThruConnectionsChanged:message];
            break;

        case kMIDIMsgSerialPortOwnerChanged:	// Added in 10.2
#if DEBUG
            NSLog(@"serial port owner changed");
#endif
            [client serialPortOwnerChanged:message];
            break;
            
        default:
#if DEBUG
            NSLog(@"unknown notification: %ld", (long)message->messageID);
#endif
            [client broadcastUnknownMIDINotification:message];
            break;
    }
}

- (void)midiSetupChanged;
{
    isHandlingSetupChange = YES;

    // Notify the objects internal to this framework about the change first, and then let
    // other objects know about it.
    [[NSNotificationCenter defaultCenter] postNotificationName:SMClientSetupChangedInternalNotification object:self];
    if (postsExternalSetupChangeNotification)
        [[NSNotificationCenter defaultCenter] postNotificationName:SMClientSetupChangedNotification object:self];

    isHandlingSetupChange = NO;
}

- (void)midiObjectAddedOrRemoved:(const MIDIObjectAddRemoveNotification *)message;
{
    NSString *notificationName;
    NSDictionary *userInfo;

    if (message->messageID == kMIDIMsgObjectAdded)
        notificationName = SMClientObjectAddedNotification;
    else
        notificationName = SMClientObjectRemovedNotification;

    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInt:(UInt32)message->parent], SMClientObjectAddedOrRemovedParent,
        [NSNumber numberWithInt:message->parentType], SMClientObjectAddedOrRemovedParentType,
        [NSNumber numberWithUnsignedInt:(UInt32)message->child], SMClientObjectAddedOrRemovedChild,
        [NSNumber numberWithInt:message->childType], SMClientObjectAddedOrRemovedChildType,
        nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];    
}

- (void)midiObjectPropertyChanged:(const MIDIObjectPropertyChangeNotification *)message;
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInt:(UInt32)message->object], SMClientObjectPropertyChangedObject,
        [NSNumber numberWithInt:message->objectType], SMClientObjectPropertyChangedType,
        (NSString *)message->propertyName, SMClientObjectPropertyChangedName,
        nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:SMClientObjectPropertyChangedNotification object:self userInfo:userInfo];    
}

- (void)midiThruConnectionsChanged:(const MIDINotification *)message;
{
    [self broadcastGenericMIDINotification:message withName:SMClientThruConnectionsChangedNotification];
}

- (void)serialPortOwnerChanged:(const MIDINotification *)message;
{
    [self broadcastGenericMIDINotification:message withName:SMClientSerialPortOwnerChangedNotification];
}

- (void)broadcastUnknownMIDINotification:(const MIDINotification *)message;
{
    [self broadcastGenericMIDINotification:message withName:SMClientMIDINotification];
}

- (void)broadcastGenericMIDINotification:(const MIDINotification *)message withName:(NSString *)notificationName;
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObject:[NSValue valueWithPointer:message] forKey:SMClientMIDINotificationStruct];

    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
}

@end
