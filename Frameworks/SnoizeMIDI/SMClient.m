#import "SMClient.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMClient (Private)

- (NSString *)_processName;

static void getMIDINotification(const MIDINotification *message, void *refCon);
- (void)_midiSetupChanged;
- (void)_broadcastUnknownMIDINotification:(const MIDINotification *)message;

@end


@implementation SMClient

DEFINE_NSSTRING(SMClientSetupChangedInternalNotification);
DEFINE_NSSTRING(SMClientSetupChangedNotification);
DEFINE_NSSTRING(SMClientMIDINotification);
DEFINE_NSSTRING(SMClientMIDINotificationID);
DEFINE_NSSTRING(SMClientMIDINotificationData);


static SMClient *sharedClient = nil;

+ (SMClient *)sharedClient;
{
    if (!sharedClient)
        sharedClient = [[self alloc] init];
    
    return sharedClient;
}

- (id)init;
{
    OSStatus status;

    if (!(self = [super init]))
        return nil;

    name = [[self _processName] retain];
    postsExternalSetupChangeNotification = YES;

    status = MIDIClientCreate((CFStringRef)name, getMIDINotification, self, &midiClient);
    if (status != noErr)
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI client (error %ld)", @"SnoizeMIDI", [self bundle], "exception with OSStatus if MIDIClientCreate() fails"), status];

    return self;
}

- (void)dealloc
{
#if DEBUG
    NSLog(@"SMClient should not be deallocated; ignoring");
#endif
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

@end


@implementation SMClient (Private)

- (NSString *)_processName;
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
        [(SMClient *)refCon _midiSetupChanged];    
    } else {
        [(SMClient *)refCon _broadcastUnknownMIDINotification:message];
    }
}

- (void)_midiSetupChanged;
{
    // Unfortunately, CoreMIDI is really messed up, and can send us a notification while we are still processing one!
    // So this method needs to be reentrant. If someone calls us while we are processing, just remember that fact,
    // and call ourself again after we're done.  (If we get multiple notifications while we're processing, they
    // will be coalesced into one update at the end.)

    static BOOL isHandlingSetupChange = NO;
    static BOOL retryAfterDone = NO;
    
    if (!isHandlingSetupChange) {
        isHandlingSetupChange = YES;
        retryAfterDone = NO;

        // Notify the objects internal to this framework about the change first, and then let
        // other objects know about it.
        [[NSNotificationCenter defaultCenter] postNotificationName:SMClientSetupChangedInternalNotification object:self];
        if (postsExternalSetupChangeNotification) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SMClientSetupChangedNotification object:self];
        }
        
        isHandlingSetupChange = NO;
        if (retryAfterDone)
            [self _midiSetupChanged];
    } else {
        retryAfterDone = YES;
    }
}

- (void)_broadcastUnknownMIDINotification:(const MIDINotification *)message;
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
