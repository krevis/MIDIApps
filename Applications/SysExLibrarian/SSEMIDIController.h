#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

@class OFScheduledEvent;
@class SSEMainWindowController;


@interface SSEMIDIController : NSObject <SMMessageDestination>
{
    IBOutlet SSEMainWindowController *windowController;

    // MIDI processing
    SMPortInputStream *inputStream;
    SMPortOrVirtualOutputStream *outputStream;
        
    // Transient data
    BOOL listenToMIDISetupChanges;
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

- (NSArray *)destinationDescriptions;
- (NSDictionary *)destinationDescription;
- (void)setDestinationDescription:(NSDictionary *)destinationDescription;

- (NSTimeInterval)pauseTimeBetweenMessages;
- (void)setPauseTimeBetweenMessages:(NSTimeInterval)value;

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
