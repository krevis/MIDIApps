#import <Foundation/Foundation.h>


@protocol SMMessageDestination <NSObject>

- (void)takeMIDIMessages:(NSArray *)messages;

@end
