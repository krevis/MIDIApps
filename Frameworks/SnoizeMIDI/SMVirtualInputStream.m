#import "SMVirtualInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMessageParser.h"


@implementation SMVirtualInputStream

- (id)initWithName:(NSString *)name uniqueID:(SInt32)uniqueID;
{
    SMClient *client;
    OSStatus status;
    MIDIEndpointRef endpointRef;
    BOOL wasPostingExternalNotification;

    if (!(self = [super init]))
        return nil;

    parser = [[SMMessageParser alloc] init];
    [parser setDelegate:self];
    
    client = [SMClient sharedClient];
        
    // We are going to be making a lot of changes, so turn off external notifications
    // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
    wasPostingExternalNotification = [client postsExternalSetupChangeNotification];
    [client setPostsExternalSetupChangeNotification:NO];

    status = MIDIDestinationCreate([client midiClient], (CFStringRef)name, [self midiReadProc], self, &endpointRef);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI virtual destination (error %ld)", @"SnoizeMIDI", [self bundle], "exception with OSStatus if MIDIDestinationCreate() fails"), status];
    }

    endpoint = [[SMDestinationEndpoint destinationEndpointWithEndpointRef:endpointRef] retain];
    if (!endpoint) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't find the virtual destination endpoint after creating it", @"SnoizeMIDI", [self bundle], "exception if we can't find an SMDestinationEndpoint after calling MIDIDestinationCreate")];
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

    [parser release];
    parser = nil;

    [super dealloc];
}

- (SMDestinationEndpoint *)endpoint;
{
    return endpoint;
}

//
// SMInputStream subclass
//

- (NSArray *)parsers;
{
    return [NSArray arrayWithObject:parser];
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    // refCon is ignored, since it only applies to connections created with MIDIPortConnectSource()
    return parser;
}

@end
