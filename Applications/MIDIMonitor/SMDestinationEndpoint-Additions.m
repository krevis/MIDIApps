#import "SMDestinationEndpoint-Additions.h"
#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@implementation SMDestinationEndpoint (SMInputStreamSource)

- (NSString *)inputStreamSourceName;
{
    return [self uniqueName];
}

- (NSNumber *)inputStreamSourceUniqueID;
{
    return [NSNumber numberWithInt:[self uniqueID]];
}

- (NSArray *)inputStreamSourceExternalDeviceNames;
{
    return [[self connectedExternalDevices] arrayByPerformingSelector:@selector(name)]; 
}

@end
