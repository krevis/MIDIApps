/*
 Copyright (c) 2001-2009, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMVirtualInputStream.h"

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMInputStreamSource.h"
#import "SMMessageParser.h"
#import "SMUtilities.h"


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

    parser = [[self createParserWithOriginatingEndpoint:nil] retain];

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

- (SMDestinationEndpoint*)endpoint
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
        SMAssert(uniqueID != 0);
    }
}

- (void)disposeEndpoint;
{
    SMAssert(endpoint != nil);

    [endpoint remove];
    [endpoint release];
    endpoint = nil;

    [parser setOriginatingEndpoint:nil];
}

@end
