//
//  SMSequence.h
//  SnoizeMIDI
//
//  Created by Kurt Revis on Sat Dec 15 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OmniFoundation/OFObject.h>

@class SMSequenceNote;

@interface SMSequence : OFObject
{
    NSMutableArray *notes;
    NSLock *notesLock;
}

- (NSArray *)notes;
- (void)addNote:(SMSequenceNote *)note;
- (void)removeNote:(SMSequenceNote *)note;

- (NSArray *)notesStartingFromBeat:(Float64)startBeat toBeat:(Float64)endBeat;
    // Returns notes which start in the interval (startBeat, endBeat]

@end
