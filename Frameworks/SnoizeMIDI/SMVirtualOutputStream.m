//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMVirtualOutputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"


@implementation SMVirtualOutputStream

- (id)initWithName:(NSString *)name uniqueID:(SInt32)uniqueID;
{
    SMClient *client;
    OSStatus status;
    MIDIEndpointRef endpointRef;
    BOOL wasPostingExternalNotification;

    if (!(self = [super init]))
        return nil;

    client = [SMClient sharedClient];
        
    // We are going to be making a lot of changes, so turn off external notifications
    // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
    wasPostingExternalNotification = [client postsExternalSetupChangeNotification];
    [client setPostsExternalSetupChangeNotification:NO];

    status = MIDISourceCreate([client midiClient], (CFStringRef)name, &endpointRef);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI virtual source (error %ld)", @"SnoizeMIDI", [self bundle], "exception with OSStatus if MIDISourceCreate() fails"), status];
    }

    endpoint = [[SMSourceEndpoint sourceEndpointWithEndpointRef:endpointRef] retain];
    if (!endpoint) {
        // NOTE If you see this fire, it is probably because we are being called in the middle of handling a MIDI setup change notification.
        // Don't do that.
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't find the virtual source endpoint after creating it", @"SnoizeMIDI", [self bundle], "exception if we can't find an SMSourceEndpoint after calling MIDISourceCreate")];
    }

    [endpoint setIsOwnedByThisProcess];
    [endpoint setUniqueID:uniqueID];
    [endpoint setManufacturerName:@"Snoize"];

    // Do this before the last modification, so one setup change notification will still happen
    [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

    [endpoint setModelName:[client name]];

    return self;
}

- (void)dealloc;
{
    if (endpoint)
        MIDIEndpointDispose([endpoint endpointRef]);

    [endpoint release];
    endpoint = nil;

    [super dealloc];
}

- (SMSourceEndpoint *)endpoint;
{
    return endpoint;
}

- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;
{
    MIDIEndpointRef endpointRef;
    OSStatus status;

    if (!(endpointRef = [endpoint endpointRef]))
        return;

    status = MIDIReceived(endpointRef, packetList);
    if (status) {
        NSLog(@"MIDIReceived(%p, %p) returned error: %ld", endpointRef, packetList, status);
    }
}

@end
