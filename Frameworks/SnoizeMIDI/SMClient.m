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
- (void)broadcastUnknownMIDINotification:(const MIDINotification *)message;

@end


@implementation SMClient

NSString *SMClientCreatedInternalNotification = @"SMClientCreatedInternalNotification";
NSString *SMClientSetupChangedInternalNotification = @"SMClientSetupChangedInternalNotification";
NSString *SMClientSetupChangedNotification = @"SMClientSetupChangedNotification";
NSString *SMClientMIDINotification = @"SMClientMIDINotification";
NSString *SMClientMIDINotificationID = @"SMClientMIDINotificationID";
NSString *SMClientMIDINotificationData = @"SMClientMIDINotificationData";


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

    name = [[self processName] retain];
    postsExternalSetupChangeNotification = YES;
    isHandlingSetupChange = NO;

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
#if DEBUG
//    NSLog(@"Got MIDI notification: %ld size: %ld", message->messageID, message->messageSize);
#endif

    if (message->messageID == kMIDIMsgSetupChanged) {
        [(SMClient *)refCon midiSetupChanged];    
    } else {
        [(SMClient *)refCon broadcastUnknownMIDINotification:message];
    }
}

- (void)midiSetupChanged;
{
    // Unfortunately, CoreMIDI is really messed up, and can send us a notification while we are still processing one!
    // So this method needs to be reentrant. If someone calls us while we are processing, just remember that fact,
    // and call ourself again after we're done.  (If we get multiple notifications while we're processing, they
    // will be coalesced into one update at the end.)

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
        if (postsExternalSetupChangeNotification) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SMClientSetupChangedNotification object:self];
        }

        isHandlingSetupChange = NO;
    } while (retryAfterDone);
}

- (void)broadcastUnknownMIDINotification:(const MIDINotification *)message;
{
    unsigned int dataSize;
    NSData *data;
    NSDictionary *userInfo;

    dataSize = message->messageSize - sizeof(MIDINotification);
    if (dataSize > 0)
        data = [NSData dataWithBytes:(message + 1) length:dataSize];
    else
        data = nil;

    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:message->messageID], SMClientMIDINotificationID, data, SMClientMIDINotificationData, nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:SMClientMIDINotification object:self userInfo:userInfo];
}

@end
