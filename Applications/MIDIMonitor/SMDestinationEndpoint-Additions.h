#import <SnoizeMIDI/SnoizeMIDI.h>


@interface SMDestinationEndpoint (SMInputStreamSource) <SMInputStreamSource>

- (NSString *)inputStreamSourceName;
- (NSNumber *)inputStreamSourceUniqueID;

@end
