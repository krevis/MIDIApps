//
//  SMSystemRealTimeMessage.h
//  SnoizeMIDI
//
//  Created by krevis on Sat Dec 08 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <SnoizeMIDI/SMMessage.h>


typedef enum _SMSystemRealTimeMessageType {
    SMSystemRealTimeMessageTypeClock = 0xF8,
    SMSystemRealTimeMessageTypeStart = 0xFA,
    SMSystemRealTimeMessageTypeContinue = 0xFB,
    SMSystemRealTimeMessageTypeStop = 0xFC,
    SMSystemRealTimeMessageTypeActiveSense = 0xFE,
    SMSystemRealTimeMessageTypeReset = 0xFF
} SMSystemRealTimeMessageType;

@interface SMSystemRealTimeMessage: SMMessage
{
}

+ (SMSystemRealTimeMessage *)systemRealTimeMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp type:(SMSystemRealTimeMessageType)aType;

- (SMSystemRealTimeMessageType)type;
- (void)setType:(SMSystemRealTimeMessageType)newType;

@end
