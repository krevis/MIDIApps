//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMSequenceNote.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMSequenceNote-Internal.h"


@implementation SMSequenceNote

- (id)init;
{
    if (![super init])
        return nil;

    return self;    
}

- (Byte)noteNumber;
{
    return noteNumber;
}

- (void)setNoteNumber:(Byte)value;
{
    noteNumber = value;
}

- (Byte)onVelocity;
{
    return onVelocity;
}

- (void)setOnVelocity:(Byte)value;
{
    OBASSERT(value < 128);
    onVelocity = value;
}

- (Byte)offVelocity;
{
    return offVelocity;
}

- (void)setOffVelocity:(Byte)value;
{
    OBASSERT(value < 128);
    offVelocity = value;
}

- (Float64)duration;
{
    return duration;
}

- (void)setDuration:(Float64)value;
{
    OBASSERT(value > 0);
    duration = value;
}

- (Float64)endPosition;
{
    // Convenience method--endPosition is derived from other values
    return position + duration;
}

- (void)setEndPosition:(Float64)value;
{
    // Convenience method--endPosition is derived from other values
    OBASSERT(value >= position);
    if (value >= position) {
        duration = value - position;
    }        
}

- (NSComparisonResult)comparePosition:(SMSequenceNote *)otherNote;
{
    if (position == otherNote->position)
        return NSOrderedSame;
    else if (position > otherNote->position)
        return NSOrderedDescending;
    else
        return NSOrderedAscending;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<SMSequenceNote %p>{position=%f, duration=%f}", self, position, duration];
}

@end


@implementation SMSequenceNote (SnoizeMIDIInternal)

- (Float64)position;
{
    return position;
}

- (void)setPosition:(Float64)value;
{
    position = value;
}

@end
