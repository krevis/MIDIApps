//
//  SMMessageParser.h
//  SnoizeMIDI.framework
//
//  Created by krevis on Sat Sep 08 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/MIDIServices.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class NSData, NSMutableData;		// Foundation

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
