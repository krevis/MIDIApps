#import <SnoizeMIDI/SMInputStream.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMMessageParser;
@class SMDestinationEndpoint;


@interface SMVirtualInputStream : SMInputStream
{
    SMDestinationEndpoint *endpoint;
    SMMessageParser *parser;
}

- (id)initWithName:(NSString *)name uniqueID:(SInt32)uniqueID;

- (SMDestinationEndpoint *)endpoint;

@end
