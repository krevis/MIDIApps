/*
 Copyright (c) 2004-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "NSArray-SMExtensions.h"


@implementation NSArray (SMExtensions)

- (NSArray *)SnoizeMIDI_arrayByMakingObjectsPerformSelector:(SEL)selector
{
    NSMutableArray *results;
    NSEnumerator *enumerator;
    id object;

    results = [NSMutableArray arrayWithCapacity:[self count]];
    enumerator = [self objectEnumerator];
    while ((object = [enumerator nextObject])) {
        id result = [object performSelector:selector];
        if (result)
            [results addObject:result];
    }

    return results;
}

- (NSArray *)SnoizeMIDI_reversedArray
{
    NSUInteger count = [self count];
    if (count < 2)
        return self;
    
    NSMutableArray *result = [self mutableCopy];
    CFMutableArrayRef cfResult = (CFMutableArrayRef)result;
    CFIndex startIndex = 0;
    CFIndex endIndex = count - 1;
    while (startIndex < endIndex) {
        CFArrayExchangeValuesAtIndices(cfResult, startIndex, endIndex);
        startIndex++;
        endIndex--;
    }
    
    return [result autorelease];
}

@end


@implementation NSMutableArray (SMExtensions)

- (void)SnoizeMIDI_removeObjectsIdenticalToObjectsInArray:(NSArray *)objectsToRemove
{
    NSMutableSet *objectsToRemoveSet = [[NSMutableSet alloc] initWithArray:objectsToRemove];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSEnumerator *oe = [self objectEnumerator];
    id obj;

    while ((obj = [oe nextObject])) {
        if (![objectsToRemoveSet containsObject:obj]) {
            [result addObject:obj];
        }
    }
    [self setArray: result];
    [result release];
    
    [objectsToRemoveSet release];
}

@end
