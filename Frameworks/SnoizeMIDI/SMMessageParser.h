#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>


@interface SMMessageParser : OFObject
{
    NSMutableData *readingSysExData;
    MIDITimeStamp startSysExTimeStamp;
    
    id<SMMessageDestination> nonretainedMessageDestination;
    id nonretainedDelegate;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)aMessageDestination;

- (id)delegate;
- (void)setDelegate:(id)value;

- (void)takePacketList:(const MIDIPacketList *)packetList;

@end


@interface NSObject (SMMessageParserDelegate)

- (void)parser:(SMMessageParser *)parser isReadingSysExData:(NSData *)sysExData;
- (void)parser:(SMMessageParser *)parser finishedReadingSysExData:(NSData *)sysExData validEOX:(BOOL)wasValid;

@end
