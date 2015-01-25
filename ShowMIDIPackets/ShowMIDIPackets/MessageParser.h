#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>


@class MessageParser;

@protocol MessageParserDelegate <NSObject>

- (void)parser:(MessageParser *)parser didReadMessages:(NSArray *)messages;

@end

@interface MessageParser : NSObject

@property (nonatomic, weak) id<MessageParserDelegate> delegate;

- (void)takePacketList:(const MIDIPacketList *)packetList;

@end
