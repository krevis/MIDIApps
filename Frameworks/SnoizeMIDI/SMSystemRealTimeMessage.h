#import <SnoizeMIDI/SMMessage.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


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
