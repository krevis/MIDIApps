//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMSystemRealTimeMessage.h"

#import "SMUtilities.h"


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
            return NSLocalizedStringFromTableInBundle(@"Clock", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Clock event");
            
        case SMSystemRealTimeMessageTypeStart:
            return NSLocalizedStringFromTableInBundle(@"Start", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Start event");

        case SMSystemRealTimeMessageTypeContinue:
            return NSLocalizedStringFromTableInBundle(@"Continue", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Continue event");
            
        case SMSystemRealTimeMessageTypeStop:
            return NSLocalizedStringFromTableInBundle(@"Stop", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Stop event");

        case SMSystemRealTimeMessageTypeActiveSense:
            return NSLocalizedStringFromTableInBundle(@"Active Sense", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Active Sense event");
        
        case SMSystemRealTimeMessageTypeReset:
            return NSLocalizedStringFromTableInBundle(@"Reset", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Reset event");

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
