#import <SnoizeMIDI/SMInputStream.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMDestinationEndpoint;


@interface SMVirtualInputStream : SMInputStream
{
    SMDestinationEndpoint *endpoint;
}

- (id)initWithName:(NSString *)name uniqueID:(SInt32)uniqueID;

- (SMDestinationEndpoint *)endpoint;

@end
