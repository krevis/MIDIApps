#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMDestinationEndpoint, SMSystemExclusiveMessage;


@interface SMSysExSendRequest : OFObject
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

- (unsigned int)bytesRemaining;
- (unsigned int)totalBytes;
- (unsigned int)bytesSent;
- (BOOL)wereAllBytesSent;

@end

// Notifications
extern NSString *SMSysExSendRequestFinishedNotification;
