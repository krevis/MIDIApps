/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
