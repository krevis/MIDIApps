//
//  SMSequence.m
//  SnoizeMIDI
//
//  Created by Kurt Revis on Sat Dec 15 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMSequence.h"
#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SMSequenceNote.h"


@interface SMSequence (Private)

- (unsigned int)_indexOfFirstNoteWithPositionGreaterThanOrEqualTo:(Float64)lowBeat atOrAfterIndex:(unsigned int)startIndex;

@end


@implementation SMSequence

- (id)init;
{
    if (![super init])
        return nil;

    notes = [[NSMutableArray alloc] init];
    notesLock = [[NSRecursiveLock alloc] init];
    
    return self;
}

- (void)dealloc;
{
    [notes release];
    notes = nil;
    [notesLock release];
    notes = nil;
    
    [super dealloc];
}

- (NSArray *)notes;
{
    // TODO need to lock notes, copy it, and then unlock?
    // depends on who uses this accessor...
    return notes;
}

- (void)addNote:(SMSequenceNote *)note;
{
    [notesLock lock];
    [notes insertObject:note inArraySortedUsingSelector:@selector(comparePosition:)];
    [notesLock unlock];
}

- (void)removeNote:(SMSequenceNote *)note;
{
    [notesLock lock];
    [notes removeObject:note fromArraySortedUsingSelector:@selector(comparePosition:)];
    [notesLock unlock];
}

- (NSArray *)notesStartingFromBeat:(Float64)startBeat toBeat:(Float64)endBeat;
{
    // Returns notes which start in the interval (startBeat, endBeat].

    unsigned int noteCount;
    NSArray *notesInInterval;
    Float64 firstNotePosition, lastNotePosition;
    unsigned int firstNoteIndex, lastNoteIndex;

    OBASSERT(startBeat < endBeat);
    
    [notesLock lock];
    // TODO This lock doesn't prevent anyone from changing the positions of the notes
    // inside of the sequence... we have no way of detecting that currently (we will need one anyway
    // to keep the array sorted).

    noteCount = [notes count];
    if (noteCount == 0) {
        [notesLock unlock];
        return nil;
    }

    firstNotePosition = [[notes objectAtIndex:0] position];
    lastNotePosition = [[notes lastObject] position];
    if (endBeat <= firstNotePosition || startBeat > lastNotePosition) {
        [notesLock unlock];
        return nil;
    }

    startBeat = MAX(firstNotePosition, startBeat);
    OBASSERT(startBeat < endBeat);

    // Find the index of the first note with position >= startBeat and position < endBeat
    firstNoteIndex = [self _indexOfFirstNoteWithPositionGreaterThanOrEqualTo:startBeat atOrAfterIndex:0];
    if (firstNoteIndex == NSNotFound || [[notes objectAtIndex:firstNoteIndex] position] >= endBeat) {
        // There are no notes in this interval
        notesInInterval = nil;
    } else {
        if (firstNoteIndex == noteCount - 1) {
            // This is the last note, so just use it
            notesInInterval = [NSArray arrayWithObject:[notes objectAtIndex:firstNoteIndex]];
        } else {
            // Find the index of the first note after firstNoteIndex with position >= endBeat.
            // Then get the subarray from (firstNoteIndex, lastNoteIndex].
            lastNoteIndex = [self _indexOfFirstNoteWithPositionGreaterThanOrEqualTo:endBeat atOrAfterIndex:firstNoteIndex + 1];
            if (lastNoteIndex == NSNotFound)
                lastNoteIndex = noteCount;
            notesInInterval = [notes subarrayWithRange:NSMakeRange(firstNoteIndex, lastNoteIndex - firstNoteIndex)];
        }
    }

    [notesLock unlock];
    return notesInInterval;    
}

- (Float64)startBeat;
{
    // Returns the position of the first note, or 0 if there are no notes.
    Float64 startBeat;
    
    [notesLock lock];

    if ([notes count] == 0)
        startBeat = 0.0;
    else
        startBeat = [[notes objectAtIndex:0] position];

    [notesLock unlock];
    return startBeat;
}

- (Float64)endBeat;
{
    // Returns the endPosition of the last note, or 0 if there are no notes.
    Float64 endBeat;

    [notesLock lock];

    if ([notes count] == 0)
        endBeat = 0.0;
    else
        endBeat = [[notes lastObject] endPosition];

    [notesLock unlock];
    return endBeat;
}

@end


@implementation SMSequence (Private)

#define TESTING 1
// TODO Turn this off before shipping

#if TESTING
- (unsigned int)_simpleIndexOfFirstNoteWithPositionGreaterThanOrEqualTo:(Float64)lowBeat atOrAfterIndex:(unsigned int)startIndex;
{
    unsigned int noteIndex, noteCount;
    
    noteCount = [notes count];
    for (noteIndex = startIndex; noteIndex < noteCount; noteIndex++) {
        if ([[notes objectAtIndex:noteIndex] position] >= lowBeat) {
            return noteIndex;
        } 
    }

    return NSNotFound;
}
#endif

- (unsigned int)_indexOfFirstNoteWithPositionGreaterThanOrEqualTo:(Float64)lowBeat atOrAfterIndex:(unsigned int)startIndex;
{
    // We know the array of notes is sorted by position, so we can do a binary search instead of a simple linear search.
    unsigned int count;
    unsigned int low, high, range;
    unsigned int returnIndex;

    count = [notes count];

    OBASSERT(startIndex < count);
    
    // Make range the lowest power of 2 which is > (count - startIndex)
    range = 1;
    while (range <= (count - startIndex))
        range <<= 1;

    low = startIndex;	// Lowest index which might be acceptable
    high = count;		// Highest index we know is acceptable (there may be lower ones we haven't found yet)
    while (range) {
        unsigned int test;
        Float64 position;

        range >>= 1;
        test = low + range;
        if (test >= high)
            continue;
        
        position = [[notes objectAtIndex:test] position];
        if (position < lowBeat) {
            // This index is too low; bump up our lower bound
            low = test + 1;
        } else {
            // We found a new upper bound
            high = test;
        }

        if (low == high)
            break;
    }

    if (low == high)
        returnIndex = low;
    else
        returnIndex = NSNotFound;

#if TESTING
    {
        unsigned int correct;

        correct = [self _simpleIndexOfFirstNoteWithPositionGreaterThanOrEqualTo:lowBeat atOrAfterIndex:startIndex];
        if (returnIndex != correct) {
            NSLog(@"*** Failed!: lowBeat = %g, startIndex = %u, wrong = %u, right = %u", lowBeat, startIndex, returnIndex, correct);
        }
    }
#endif

    return returnIndex;
}

@end
