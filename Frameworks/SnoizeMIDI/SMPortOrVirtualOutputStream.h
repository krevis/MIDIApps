#import <SnoizeMIDI/SMPortOrVirtualStream.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@interface SMPortOrVirtualOutputStream : SMPortOrVirtualStream <SMMessageDestination>
{
    struct {
        unsigned int ignoresTimeStamps:1;
    } flags;
}

- (BOOL)ignoresTimeStamps;
- (void)setIgnoresTimeStamps:(BOOL)value;
    // If YES, then ignore the timestamps in the messages we receive, and send immediately instead

@end
