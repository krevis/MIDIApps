/*
 Copyright (c) 2003-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMInvalidMessage.h"

#import "SMUtilities.h"


@implementation SMInvalidMessage : SMMessage

+ (SMInvalidMessage *)invalidMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData
{
    SMInvalidMessage *message;
    
    message = [[[SMInvalidMessage alloc] initWithTimeStamp:aTimeStamp statusByte:0x00] autorelease];
    // statusByte is ignored
    [message setData:aData];

    return message;
}

- (void)dealloc
{
    [data release];

    [super dealloc];
}

//
// SMMessage overrides
//

- (id)copyWithZone:(NSZone *)zone;
{
    SMInvalidMessage *newMessage;
    
    newMessage = [super copyWithZone:zone];
    [newMessage setData:data];

    return newMessage;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:data forKey:@"data"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder])) {
        id obj = [decoder decodeObjectForKey:@"data"];
        if (obj && [obj isKindOfClass:[NSData class]]) {
            data = [obj retain];
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
    return SMMessageTypeInvalid;
}

- (NSUInteger)otherDataLength
{
    return [data length];
}

- (const Byte *)otherDataBuffer;
{
    return [[self otherData] bytes];    
}

- (NSData *)otherData
{
    return [self data];
}

- (NSString *)typeForDisplay;
{
    return NSLocalizedStringFromTableInBundle(@"Invalid", @"SnoizeMIDI", SMBundleForObject(self), "displayed type of Invalid event");
}

- (NSString*)dataForDisplay
{
    return [self sizeForDisplay];
}


//
// Additional API
//

- (NSData *)data;
{
    return data;
}

- (void)setData:(NSData *)newData;
{
    if (data != newData) {
        [data release];
        data = [newData retain];
    }
}

- (NSString *)sizeForDisplay;
{
    return [NSString stringWithFormat:
        NSLocalizedStringFromTableInBundle(@"%@ bytes", @"SnoizeMIDI", SMBundleForObject(self), "Invalid message length format string"),
        [SMMessage formatLength:[self otherDataLength]]];
}

@end
