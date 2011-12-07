/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMMessageMult.h"


@implementation SMMessageMult

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    destinations = [[NSMutableArray alloc] init];

    return self;
}

- (void)dealloc;
{
    [destinations release];
    destinations = nil;

    [super dealloc];
}

- (NSArray *)destinations;
{
    return [NSArray arrayWithArray:destinations];
}

- (void)setDestinations:(NSArray *)newDestinations;
{
    if (destinations != newDestinations) {
        [destinations release];
        destinations = [newDestinations mutableCopy];
    }
}

- (void)addDestination:(id<SMMessageDestination>)destination;
{
    [destinations addObject:destination];
}

- (void)removeDestination:(id<SMMessageDestination>)destination;
{
    [destinations removeObject:destination];
}

- (void)takeMIDIMessages:(NSArray *)messages;
{
    [destinations makeObjectsPerformSelector:@selector(takeMIDIMessages:) withObject:messages];
}

@end
