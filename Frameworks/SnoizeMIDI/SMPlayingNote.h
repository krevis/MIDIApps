#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMSequenceNote;


@interface SMPlayingNote : OFObject
{
    SMSequenceNote *note;
    MIDITimeStamp endTime;
}

- (id)initWithNote:(SMSequenceNote *)aNote endTime:(MIDITimeStamp)anEndTime;

- (SMSequenceNote *)note;
- (MIDITimeStamp)endTime;

@end
