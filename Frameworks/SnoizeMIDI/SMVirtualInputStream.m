//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMVirtualInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMInputStreamSource.h"
#import "SMMessageParser.h"


@interface SMVirtualInputStream (Private)

- (BOOL)isActive;
- (void)setIsActive:(BOOL)value;

- (void)createEndpoint;
- (void)disposeEndpoint;

@end


@implementation SMVirtualInputStream

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    endpointName = [[[SMClient sharedClient] name] retain];
    uniqueID = [SMEndpoint generateNewUniqueID];

    inputStreamSource = [[SMSimpleInputStreamSource alloc] initWithName:endpointName];

    parser = [[self newParserWithOriginatingEndpoint:nil] retain];

    return self;
}

- (void)dealloc;
{
    [self setIsActive:NO];

    [endpointName release];
    endpointName = nil;
    
    [inputStreamSource release];
    inputStreamSource = nil;
    
    [parser release];
    parser = nil;

    [super dealloc];
}

- (SInt32)uniqueID;
{
    return uniqueID;
}

- (void)setUniqueID:(SInt32)value;
{
    uniqueID = value;
    if (endpoint)
        [endpoint setUniqueID:value];
}

- (NSString *)virtualEndpointName;
{
    return endpointName;
}

- (void)setVirtualEndpointName:(NSString *)value;
{
    if (endpointName != value) {
        [endpointName release];
        endpointName = [value copy];

        if (endpoint)
            [endpoint setName:endpointName];
    }
}

- (void)setInputSourceName:(NSString *)value;
{
    [inputStreamSource setName:value];
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

- (NSArray *)inputSources;
{
    return [NSArray arrayWithObject:inputStreamSource];
}

- (NSSet *)selectedInputSources;
{
    if ([self isActive])
        return [NSSet setWithObject:inputStreamSource];
    else
        return [NSSet set];
}

- (void)setSelectedInputSources:(NSSet *)sources;
{
    [self setIsActive:(sources && [sources containsObject:inputStreamSource])];
}

//
// SMInputStream overrides
//

- (id)persistentSettings;
{
    if ([self isActive])
        return [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:uniqueID] forKey:@"uniqueID"];
    else
        return nil;
}

- (NSArray *)takePersistentSettings:(id)settings;
{
    if (settings) {
        [self setUniqueID:[[settings objectForKey:@"uniqueID"] intValue]];
        [self setIsActive:YES];
    } else {
        [self setIsActive:NO];
    }

    return nil;
}

@end


@implementation SMVirtualInputStream (Private)

- (BOOL)isActive;
{
    return (endpoint != nil);
}

- (void)setIsActive:(BOOL)value;
{
    if (value && !endpoint)
        [self createEndpoint];
    else if (!value && endpoint)
        [self disposeEndpoint];

    OBASSERT([self isActive] == value);
}

- (void)createEndpoint;
{
    SMClient *client;
    OSStatus status;
    MIDIEndpointRef endpointRef;
    BOOL wasPostingExternalNotification;

    client = [SMClient sharedClient];

    // We are going to be making a lot of changes, so turn off external notifications
    // for a while (until we're done).  Internal notifications are still necessary and aren't very slow.
    wasPostingExternalNotification = [client postsExternalSetupChangeNotification];
    [client setPostsExternalSetupChangeNotification:NO];

    status = MIDIDestinationCreate([client midiClient], (CFStringRef)endpointName, [self midiReadProc], self, &endpointRef);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't create a MIDI virtual destination (error %ld)", @"SnoizeMIDI", [self bundle], "exception with OSStatus if MIDIDestinationCreate() fails"), status];
    }

    endpoint = [[SMDestinationEndpoint destinationEndpointWithEndpointRef:endpointRef] retain];
    if (!endpoint) {
        // NOTE If you see this fire, it is probably because we are being called in the middle of handling a MIDI setup change notification.
        // Don't do that.
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't find the virtual destination endpoint after creating it", @"SnoizeMIDI", [self bundle], "exception if we can't find an SMDestinationEndpoint after calling MIDIDestinationCreate")];
    }

    [endpoint setIsOwnedByThisProcess];
    [endpoint setUniqueID:uniqueID];
    [endpoint setManufacturerName:@"Snoize"];

    // Do this before the last modification, so one setup change notification will still happen
    [client setPostsExternalSetupChangeNotification:wasPostingExternalNotification];

    [endpoint setModelName:[client name]];

    [parser setOriginatingEndpoint:endpoint];
}

- (void)disposeEndpoint;
{
    OBASSERT(endpoint != nil);
    if (!endpoint)
        return;

    MIDIEndpointDispose([endpoint endpointRef]);
    [endpoint release];
    endpoint = nil;

    [parser setOriginatingEndpoint:nil];
}

@end
