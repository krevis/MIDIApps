//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMClient.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


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
        if (sharedClient)
            [[NSNotificationCenter defaultCenter] postNotificationName:SMClientCreatedInternalNotification object:sharedClient];
    }

    return sharedClient;
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
        NSLog(@"Couldn't create a MIDI client (error %ld)", status);
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

- (void *)coreMIDIFunctionNamed:(NSString *)functionName;
{
    // This method is used to look up CoreMIDI functions which may or may not exist.
    // (For example, MIDIEntityGetDevice(), which is present in 10.2 but not 10.1.)
    // If we linked against the function directly, we could no longer run on 10.1 since dyld
    // would be unable to find that symbol. So we look it up at runtime instead.
    //
    // TODO: This isn't actually true.  We can still reference the function (linking against it normally)
    // and still be able to launch; the problem is with constants.
    
    if (functionName && coreMIDIFrameworkBundle)
        return CFBundleGetFunctionPointerForName(coreMIDIFrameworkBundle, (CFStringRef)functionName);
    else
        return NULL;    
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
            NSLog(@"unknown notification: %d", message->messageID);
#endif
            [client broadcastUnknownMIDINotification:message];
            break;
    }
}

- (void)midiSetupChanged;
{
    // Unfortunately, CoreMIDI in 10.1.x and earlier has a bug: CoreMIDI calls will run the thread's run loop
    // in its default mode (instead of a special private mode). Since CoreMIDI also delivers notifications when
    // this mode runs, we can get notifications inside any CoreMIDI call that we make. It may even deliver another
    // notification while we are in the middle of reacting to the first one!
    //
    // So this method needs to be reentrant. If someone calls us while we are processing, just remember that fact,
    // and call ourself again after we're done.  (If we get multiple notifications while we're processing, they
    // will be coalesced into one update at the end.)
    //
    // Fortunately the bug has been fixed in 10.2. This code isn't really expensive, so it doesn't hurt to leave it in.

    static BOOL retryAfterDone = NO;

    if (isHandlingSetupChange) {
        retryAfterDone = YES;
        return;
    }

    do {
        isHandlingSetupChange = YES;
        retryAfterDone = NO;

        // Notify the objects internal to this framework about the change first, and then let
        // other objects know about it.
        [[NSNotificationCenter defaultCenter] postNotificationName:SMClientSetupChangedInternalNotification object:self];
        if (postsExternalSetupChangeNotification)
            [[NSNotificationCenter defaultCenter] postNotificationName:SMClientSetupChangedNotification object:self];

        isHandlingSetupChange = NO;
    } while (retryAfterDone);
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
        [NSValue valueWithPointer:message->parent], SMClientObjectAddedOrRemovedParent,
        [NSNumber numberWithInt:message->parentType], SMClientObjectAddedOrRemovedParentType,
        [NSValue valueWithPointer:message->child], SMClientObjectAddedOrRemovedChild,
        [NSNumber numberWithInt:message->childType], SMClientObjectAddedOrRemovedChildType,
        nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];    
}

- (void)midiObjectPropertyChanged:(const MIDIObjectPropertyChangeNotification *)message;
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSValue valueWithPointer:message->object], SMClientObjectPropertyChangedObject,
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
