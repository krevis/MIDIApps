#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMSystemExclusiveMessage;

@interface SMSysExSendRequest : OFObject
{
    MIDISysexSendRequest request;
    NSData *fullMessageData;
    SMSystemExclusiveMessage *message;
}

+ (SMSysExSendRequest *)sysExSendRequestWithMessage:(SMSystemExclusiveMessage *)aMessage endpoint:(MIDIEndpointRef)endpointRef;

- (id)initWithMessage:(SMSystemExclusiveMessage *)aMessage endpoint:(MIDIEndpointRef)endpointRef;

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
