#import <SnoizeMIDI/SMOutputStream.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@class SMSourceEndpoint;


@interface SMVirtualOutputStream : SMOutputStream
{
    SMSourceEndpoint *endpoint;
}

- (id)initWithName:(NSString *)name uniqueID:(SInt32)uniqueID;

- (SMSourceEndpoint *)endpoint;

@end
