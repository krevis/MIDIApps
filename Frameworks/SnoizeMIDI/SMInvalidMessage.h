//
// Copyright 2003 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SMMessage.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMInvalidMessage : SMMessage
{
    NSData *data;
}

+ (SMInvalidMessage *)invalidMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData;

- (NSData *)data;
- (void)setData:(NSData *)newData;

- (NSString *)sizeForDisplay;

@end
