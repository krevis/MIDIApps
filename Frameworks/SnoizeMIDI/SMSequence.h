#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>

@class SMSequenceNote;


@interface SMSequence : OFObject
{
    NSMutableArray *notes;
    NSRecursiveLock *notesLock;
}

- (void)addNote:(SMSequenceNote *)note;
- (void)removeNote:(SMSequenceNote *)note;

- (Float64)positionForNote:(SMSequenceNote *)note;
- (void)setPosition:(Float64)newPosition forNote:(SMSequenceNote *)note;

- (NSArray *)notesStartingFromBeat:(Float64)startBeat toBeat:(Float64)endBeat;
    // Returns notes which start in the interval (startBeat, endBeat]

// TODO Remove these if no one ever uses them
- (Float64)startBeat;
    // Returns the position of the first note. If there are no notes, returns 0.
- (Float64)endBeat;
    // Returns the endPosition of the last note. If there are no notes, returns 0.

@end
