#import "SMPlayingNote.h"
#import "SMSequenceNote.h"


@implementation SMPlayingNote

- (id)initWithNote:(SMSequenceNote *)aNote endTime:(MIDITimeStamp)anEndTime
{
    if (!(self = [super init]))
        return nil;

    note = [aNote retain];
    endTime = anEndTime;

    return self;
}

- (void)dealloc
{
    [note release];
    [super dealloc];
}

- (SMSequenceNote *)note;
{
    return note;
}

- (MIDITimeStamp)endTime;
{
    return endTime;
}

@end
