#import "SMDestinationEndpoint-Additions.h"


@implementation SMDestinationEndpoint (SMInputStreamSource)

- (NSString *)inputStreamSourceName;
{
    return [self shortName];
}

- (NSNumber *)inputStreamSourceUniqueID;
{
    return [NSNumber numberWithInt:[self uniqueID]];
}

@end
