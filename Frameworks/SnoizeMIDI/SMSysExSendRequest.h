//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMDestinationEndpoint, SMSystemExclusiveMessage;


@interface SMSysExSendRequest : NSObject
{
    MIDISysexSendRequest request;
    NSData *fullMessageData;
    SMSystemExclusiveMessage *message;
}

+ (SMSysExSendRequest *)sysExSendRequestWithMessage:(SMSystemExclusiveMessage *)aMessage endpoint:(SMDestinationEndpoint *)endpoint;

- (id)initWithMessage:(SMSystemExclusiveMessage *)aMessage endpoint:(SMDestinationEndpoint *)endpoint;

- (SMSystemExclusiveMessage *)message;

- (void)send;
- (BOOL)cancel;
    // Returns YES if the request was cancelled before it was finished sending; NO if it was already finished.
    // In either case, SMSysExSendRequestFinishedNotification will be posted.

- (unsigned int)bytesRemaining;
- (unsigned int)totalBytes;
- (unsigned int)bytesSent;
- (BOOL)wereAllBytesSent;

@end

// Notifications
extern NSString *SMSysExSendRequestFinishedNotification;
