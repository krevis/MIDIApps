#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSEOutputStreamDestination.h"

@class OFScheduledEvent;
@class SSEMainWindowController;
@class SSECombinationOutputStream;


@interface SSEMIDIController : NSObject <SMMessageDestination>
{
    SSEMainWindowController *nonretainedMainWindowController;

    // MIDI processing
    SMPortInputStream *inputStream;
    SSECombinationOutputStream *outputStream;
        
    // Transient data
    NSMutableArray *messages;
    
    // ... for listening for sysex
    BOOL listeningToMessages;
    BOOL listenToMultipleMessages;
    unsigned int messageBytesRead;
    unsigned int totalBytesRead;

    // ... for sending sysex
    NSTimeInterval pauseTimeBetweenMessages;
    NSLock *sendProgressLock;
    SMSysExSendRequest *nonretainedCurrentSendRequest;
    unsigned int sendingMessageCount;
    unsigned int sendingMessageIndex;
    unsigned int bytesToSend;
    unsigned int bytesSent;
    OFScheduledEvent *sendNextMessageEvent;
    BOOL sendCancelled;
}

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController;

- (NSArray *)destinations;
- (NSArray *)groupedDestinations;
- (id <SSEOutputStreamDestination>)selectedDestination;
- (void)setSelectedDestination:(id <SSEOutputStreamDestination>)destination;

- (NSArray *)messages;
- (void)setMessages:(NSArray *)value;

// Listening to sysex messages

- (void)listenForOneMessage;
- (void)listenForMultipleMessages;
- (void)cancelMessageListen;
- (void)doneWithMultipleMessageListen;

- (void)getMessageCount:(unsigned int *)messageCountPtr bytesRead:(unsigned int *)bytesReadPtr totalBytesRead:(unsigned int *)totalBytesReadPtr;

// Sending sysex messages

- (void)sendMessages;
- (void)cancelSendingMessages;

- (void)getMessageCount:(unsigned int *)messageCountPtr messageIndex:(unsigned int *)messageIndexPtr bytesToSend:(unsigned int *)bytesToSendPtr bytesSent:(unsigned int *)bytesSentPtr;

@end

// Preferences keys
extern NSString *SSESelectedDestinationPreferenceKey;
extern NSString *SSEHasShownSysExWorkaroundWarningPreferenceKey;
extern NSString *SSESysExReadTimeOutPreferenceKey;
extern NSString *SSESysExIntervalBetweenSentMessagesPreferenceKey;

// Notifications
extern NSString *SSEMIDIControllerReadStatusChangedNotification;
extern NSString *SSEMIDIControllerReadFinishedNotification;
extern NSString *SSEMIDIControllerSendWillStartNotification;
extern NSString *SSEMIDIControllerSendFinishedNotification;
    // userInfo has NSNumber for key "success" indicating if all messages were sent
extern NSString *SSEMIDIControllerSendFinishedImmediatelyNotification;
