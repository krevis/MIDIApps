#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class SMSystemExclusiveMessage;


@interface SMMessageParser : OFObject
{
    NSMutableData *readingSysExData;
    NSLock *readingSysExLock;
    MIDITimeStamp startSysExTimeStamp;
    NSTimer *sysExTimeOutTimer;
    NSTimeInterval sysExTimeOut;
    
    id<SMMessageDestination> nonretainedMessageDestination;
    id nonretainedDelegate;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)aMessageDestination;

- (id)delegate;
- (void)setDelegate:(id)value;

- (NSTimeInterval)sysExTimeOut;
- (void)setSysExTimeOut:(NSTimeInterval)value;

- (void)takePacketList:(const MIDIPacketList *)packetList;

- (BOOL)cancelReceivingSysExMessage;
    // Returns YES if it can successfully cancel a sysex message which is being received, and NO otherwise.

@end


@interface NSObject (SMMessageParserDelegate)

- (void)parser:(SMMessageParser *)parser isReadingSysExWithLength:(unsigned int)length;
- (void)parser:(SMMessageParser *)parser finishedReadingSysExMessage:(SMSystemExclusiveMessage *)message;

@end
