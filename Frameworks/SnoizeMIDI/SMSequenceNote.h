#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>


@interface SMSequenceNote : OFObject
{
    Byte noteNumber;
    Byte onVelocity;
    Byte offVelocity;
    Float64 position;		// beats
    Float64 duration;	// beats
}

- (Byte)noteNumber;
- (void)setNoteNumber:(Byte)value;

- (Byte)onVelocity;
- (void)setOnVelocity:(Byte)value;

- (Byte)offVelocity;
- (void)setOffVelocity:(Byte)value;

- (Float64)duration;
- (void)setDuration:(Float64)value;

- (Float64)endPosition;
- (void)setEndPosition:(Float64)value;
    // Keeps the note in the same position, and alters the duration

- (NSComparisonResult)comparePosition:(SMSequenceNote *)otherNote;

@end
