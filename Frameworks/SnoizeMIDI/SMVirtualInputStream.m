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
    uniqueID = 0;	// Let CoreMIDI assign a unique ID to the virtual endpoint when it is created

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

- (MIDIUniqueID)uniqueID;
{
    return uniqueID;
}

- (void)setUniqueID:(MIDIUniqueID)value;
{
    uniqueID = value;
    if (endpoint) {
        if (![endpoint setUniqueID:value])
            uniqueID = [endpoint uniqueID];	// we tried to change the unique ID, but failed
    }
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

- (id<SMInputStreamSource>)streamSourceForParser:(SMMessageParser *)aParser;
{
    return inputStreamSource;
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
}

- (void)createEndpoint;
{
    endpoint = [[SMDestinationEndpoint createVirtualDestinationEndpointWithName:endpointName readProc:[self midiReadProc] readProcRefCon:self uniqueID:uniqueID] retain];
    if (endpoint) {
        [parser setOriginatingEndpoint:endpoint];

        // We requested a specific uniqueID earlier, but we might not have gotten it.
        // We have to update our idea of what it is, regardless.
        uniqueID = [endpoint uniqueID];
        OBASSERT(uniqueID != 0);
    }
}

- (void)disposeEndpoint;
{
    OBASSERT(endpoint != nil);

    [endpoint remove];
    [endpoint release];
    endpoint = nil;

    [parser setOriginatingEndpoint:nil];
}

@end
