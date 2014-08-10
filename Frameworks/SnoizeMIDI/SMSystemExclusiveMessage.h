/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <SnoizeMIDI/SMMessage.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMSystemExclusiveMessage : SMMessage
    // TODO Should this be a SMSystemCommonMessage too? Would we gain anything from that?
{
    NSData *data;
    // data does not include the starting 0xF0 or the ending 0xF7 (EOX)
    
    struct {
        unsigned int wasReceivedWithEOX:1;
    } flags;

    NSMutableData *cachedDataWithEOX;
}

+ (SMSystemExclusiveMessage *)systemExclusiveMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData;
    // data should NOT include the starting 0xF0 or the ending 0xF7 (EOX)

+ (NSArray *)systemExclusiveMessagesInData:(NSData *)someData;
+ (NSData *)dataForSystemExclusiveMessages:(NSArray *)messages;

+ (NSArray *)systemExclusiveMessagesInStandardMIDIFile:(NSString *)path;
+ (BOOL)writeSystemExclusiveMessages:(NSArray *)messages toStandardMIDIFile:(NSString *)path;


    // Data without the starting 0xF0 or the ending 0xF7 (if any)
- (NSData *)data;
- (void)setData:(NSData *)newData;

- (BOOL)wasReceivedWithEOX;
- (void)setWasReceivedWithEOX:(BOOL)value;

    // Data without the starting 0xF0, always with ending 0xF7
- (NSData *)otherData;
- (NSUInteger)otherDataLength;

    // Data as received, without starting 0xF0 -- may or may not include 0xF7
- (NSData *)receivedData;
- (NSUInteger)receivedDataLength;

    // Data as received, with 0xF0 at start -- may or may not include 0xF7
- (NSData *)receivedDataWithStartByte;
- (NSUInteger)receivedDataWithStartByteLength;

    // Data with leading 0xF0 and ending 0xF7
- (NSData *)fullMessageData;
- (NSUInteger)fullMessageDataLength;

- (NSData *)manufacturerIdentifier;
    // May be 1 to 3 bytes in length, or nil if a value can't be determined
- (NSString *)manufacturerName;

- (NSString *)sizeForDisplay;
    // "<receivedDataWithStartByteLength> bytes"

@end
