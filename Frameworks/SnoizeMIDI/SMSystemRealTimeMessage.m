//
//  SMSystemRealTimeMessage.m
//  SnoizeMIDI
//
//  Created by krevis on Sat Dec 08 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMSystemRealTimeMessage.h"
#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@implementation SMSystemRealTimeMessage

+ (SMSystemRealTimeMessage *)systemRealTimeMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp type:(SMSystemRealTimeMessageType)aType
{
    SMSystemRealTimeMessage *message;
    
    message = [[[SMSystemRealTimeMessage alloc] initWithTimeStamp:aTimeStamp statusByte:aType] autorelease];
    
    return message;
}

//
// SMMessage overrides
//

- (SMMessageType)messageType;
{
    switch ([self type]) {
        case SMSystemRealTimeMessageTypeClock:
            return SMMessageTypeClock;
            
        case SMSystemRealTimeMessageTypeStart:
            return SMMessageTypeStart;

        case SMSystemRealTimeMessageTypeContinue:
            return SMMessageTypeContinue;
            
        case SMSystemRealTimeMessageTypeStop:
            return SMMessageTypeStop;

        case SMSystemRealTimeMessageTypeActiveSense:
            return SMMessageTypeActiveSense;
        
        case SMSystemRealTimeMessageTypeReset:
            return SMMessageTypeReset;

        default:
            return SMMessageTypeUnknown;
    }
}

- (NSString *)typeForDisplay;
{
    switch ([self type]) {
        case SMSystemRealTimeMessageTypeClock:
            return NSLocalizedStringFromTableInBundle(@"Clock", @"SnoizeMIDI", [self bundle], "displayed type of Clock event");
            
        case SMSystemRealTimeMessageTypeStart:
            return NSLocalizedStringFromTableInBundle(@"Start", @"SnoizeMIDI", [self bundle], "displayed type of Start event");

        case SMSystemRealTimeMessageTypeContinue:
            return NSLocalizedStringFromTableInBundle(@"Continue", @"SnoizeMIDI", [self bundle], "displayed type of Continue event");
            
        case SMSystemRealTimeMessageTypeStop:
            return NSLocalizedStringFromTableInBundle(@"Stop", @"SnoizeMIDI", [self bundle], "displayed type of Stop event");

        case SMSystemRealTimeMessageTypeActiveSense:
            return NSLocalizedStringFromTableInBundle(@"Active Sense", @"SnoizeMIDI", [self bundle], "displayed type of Active Sense event");
        
        case SMSystemRealTimeMessageTypeReset:
            return NSLocalizedStringFromTableInBundle(@"Reset", @"SnoizeMIDI", [self bundle], "displayed type of Reset event");

        default:
            return [super typeForDisplay];
    }
}

//
// Additional API
//

- (SMSystemRealTimeMessageType)type;
{
    return statusByte;
}

- (void)setType:(SMSystemRealTimeMessageType)newType;
{
    statusByte = newType;
}

@end
