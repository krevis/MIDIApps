//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSEOutputStreamDestination.h"


@interface SSECombinationOutputStream : OFObject <SMMessageDestination>
{
    SMVirtualOutputStream *virtualStream;
    SMPortOutputStream *portStream;

    SSESimpleOutputStreamDestination *virtualStreamDestination;
    SInt32 virtualEndpointUniqueID;
    NSString *virtualEndpointName;

    struct {
        unsigned int ignoresTimeStamps:1;
        unsigned int sendsSysExAsynchronously:1;
    } flags;
}

- (NSArray *)destinations;
- (NSArray *)groupedDestinations;
    // Returns an array of arrays. Each of the 2nd level arrays contains destinations that are of the same kind.
    // (That is, the first array has destinations for the port stream, the second array has destinations for the virtual stream, etc.)

- (id <SSEOutputStreamDestination>)selectedDestination;
- (void)setSelectedDestination:(id <SSEOutputStreamDestination>)aDestination;

- (void)setVirtualDisplayName:(NSString *)newName;

- (NSDictionary *)persistentSettings;
- (NSString *)takePersistentSettings:(NSDictionary *)settings;
    // If the endpoint indicated by the persistent settings couldn't be found, its name is returned

- (id)stream;
    // Returns the actual stream in use (either virtualStream or portStream)

    // Methods which are passed on to the relevant stream:

- (BOOL)ignoresTimeStamps;
- (void)setIgnoresTimeStamps:(BOOL)value;
    // If YES, then ignore the timestamps in the messages we receive, and send immediately instead

- (BOOL)sendsSysExAsynchronously;
- (void)setSendsSysExAsynchronously:(BOOL)value;
    // If YES, then use MIDISendSysex() to send sysex messages. Otherwise, use plain old MIDI packets.
    // (This can only work on port streams, not virtual ones.)
- (BOOL)canSendSysExAsynchronously;

- (void)cancelPendingSysExSendRequests;
- (SMSysExSendRequest *)currentSysExSendRequest;

@end

// Notifications
extern NSString *SSECombinationOutputStreamSelectedDestinationDisappearedNotification;
extern NSString *SSECombinationOutputStreamDestinationListChangedNotification;

// This class also reposts the following notifications from its SMPortOutputStream, with 'self' as the object:
//	SMPortOutputStreamWillStartSysExSendNotification
// 	SMPortOutputStreamFinishedSysExSendNotification
