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

@implementation SMSequence

- (id)init;
{
    if (![super init])
        return nil;

    notes = [[NSMutableArray alloc] init];
    notesLock = [[NSLock alloc] init];
    
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

    unsigned int noteIndex, noteCount;
    NSMutableArray *notesInInterval;

    [notesLock lock];
    // TODO This lock doesn't prevent anyone from changing the positions of the notes
    // inside of the sequence... we have no way of detecting that currently (we will need one anyway
    // to keep the array sorted).
    
    noteCount = [notes count];
    if (noteCount == 0) {
        [notesLock unlock];
        return nil;
    }

    // TODO We should do something clever, given that we know the array is sorted.
    // (see OmniFoundation -[NSArray indexOfObject:inArraySortedUsingSelector:])
    notesInInterval = [NSMutableArray arrayWithCapacity:noteCount];    
    for (noteIndex = 0; noteIndex < noteCount; noteIndex++) {
        SMSequenceNote *note;
        Float64 position;

        note = [notes objectAtIndex:noteIndex];
        position = [note position];
        if (position >= startBeat) {
            if (position < endBeat) {
                [notesInInterval addObject:note];
            } else {
                // The array is sorted, so there can be no more notes in range after this
                break;
            }
        }
    }

    [notesLock unlock];

    return notesInInterval;
}

@end
