#import <SnoizeMIDI/SnoizeMIDI.h>


@interface SMDestinationEndpoint (SMInputStreamSource)
// TODO how to make this indicate that SMDestination now implements the <SMInputStreamSource> protocol?

- (NSString *)inputStreamSourceName;
- (NSNumber *)inputStreamSourceUniqueID;

@end
