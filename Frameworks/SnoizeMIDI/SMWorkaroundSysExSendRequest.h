//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SMSysExSendRequest.h>


@interface SMWorkaroundSysExSendRequest : SMSysExSendRequest
{
    UInt32 realBytesToSend;
    MIDICompletionProc realCompletionProc;
    BOOL reallyComplete;
    UInt32 bytesInLastPacket;
}

@end
