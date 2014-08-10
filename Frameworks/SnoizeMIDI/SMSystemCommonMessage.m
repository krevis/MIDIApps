/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMSystemCommonMessage.h"

#import "SMUtilities.h"


@implementation SMSystemCommonMessage

+ (SMSystemCommonMessage *)systemCommonMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp type:(SMSystemCommonMessageType)aType data:(const Byte *)aData length:(UInt16)aLength
{
    SMSystemCommonMessage *message;
    
    message = [[[SMSystemCommonMessage alloc] initWithTimeStamp:aTimeStamp statusByte:aType] autorelease];

    SMAssert(aLength <= 2);
    if (aLength >= 1)
        message->dataBytes[0] = aData[0];
    if (aLength == 2)
        message->dataBytes[1] = aData[1];
    
    return message;
}

//
// SMMessage overrides
//

- (id)copyWithZone:(NSZone *)zone;
{
    SMSystemCommonMessage *newMessage;
    
    newMessage = [super copyWithZone:zone];
    newMessage->dataBytes[0] = dataBytes[0];
    newMessage->dataBytes[1] = dataBytes[1];

    return newMessage;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeBytes:dataBytes length:2 forKey:@"dataBytes"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder])) {
        NSUInteger len;
        const uint8_t *decodedBytes = [decoder decodeBytesForKey:@"dataBytes" returnedLength:&len];
        if (decodedBytes && len == 2) {
            dataBytes[0] = decodedBytes[0];
            dataBytes[1] = decodedBytes[1];
        } else {
            goto fail;
        }
    }
    
    return self;
    
fail:
    [self release];
    return nil;
}

- (SMMessageType)messageType;
{
    switch ([self type]) {
        case SMSystemCommonMessageTypeTimeCodeQuarterFrame:
            return SMMessageTypeTimeCode;
            
        case SMSystemCommonMessageTypeSongPositionPointer:
            return SMMessageTypeSongPositionPointer;
            
        case SMSystemCommonMessageTypeSongSelect:
            return SMMessageTypeSongSelect;
            
        case SMSystemCommonMessageTypeTuneRequest:
            return SMMessageTypeTuneRequest;

        default:
            return SMMessageTypeUnknown;
    }
}

- (NSUInteger)otherDataLength;
{
    switch ([self type]) {
        case SMSystemCommonMessageTypeTuneRequest:
        default:
            return 0;
            break;    

        case SMSystemCommonMessageTypeTimeCodeQuarterFrame:
        case SMSystemCommonMessageTypeSongSelect:
            return 1;
            break;

        case SMSystemCommonMessageTypeSongPositionPointer:
            return 2;
            break;
    }
}

- (const Byte *)otherDataBuffer;
{
    return dataBytes;
}

- (NSString *)typeForDisplay;
{
    switch ([self type]) {
        case SMSystemCommonMessageTypeTimeCodeQuarterFrame:
            return NSLocalizedStringFromTableInBundle(@"MTC Quarter Frame", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of MTC Quarter Frame event");
            
        case SMSystemCommonMessageTypeSongPositionPointer:
            return NSLocalizedStringFromTableInBundle(@"Song Position Pointer", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Song Position Pointer event");
            
        case SMSystemCommonMessageTypeSongSelect:
            return NSLocalizedStringFromTableInBundle(@"Song Select", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Song Select event");
            
        case SMSystemCommonMessageTypeTuneRequest:
            return NSLocalizedStringFromTableInBundle(@"Tune Request", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Tune Request event");

        default:
            return [super typeForDisplay];
    }
}


//
// Additional API
//

- (SMSystemCommonMessageType)type;
{
    return statusByte;
}

- (void)setType:(SMSystemCommonMessageType)newType;
{
    statusByte = newType;
}

- (Byte)dataByte1;
{
    return dataBytes[0];
}

- (void)setDataByte1:(Byte)newValue;
{
    SMAssert([self otherDataLength] >= 1);
    dataBytes[0] = newValue;
}

- (Byte)dataByte2;
{
    return dataBytes[1];
}

- (void)setDataByte2:(Byte)newValue;
{
    SMAssert([self otherDataLength] >= 2);
    dataBytes[1] = newValue;
}

@end
