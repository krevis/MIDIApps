#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

@class SSEMainWindowController;


@interface SSEMainController : NSObject <SMMessageDestination>
{
    IBOutlet SSEMainWindowController *windowController;

    // MIDI processing
    SMPortOrVirtualInputStream *inputStream;
    SMPortOrVirtualOutputStream *outputStream;
    
    // Transient data
    BOOL listenToMIDISetupChanges;

    // ... for listening for sysex 
    BOOL listeningToMessages;
    BOOL listenToMultipleMessages;

    NSMutableArray *messages;
    unsigned int messageBytesRead;
    unsigned int totalBytesRead;

    // ... for sending sysex
    SMSysExSendRequest *currentSendRequest;
}

- (NSArray *)sourceDescriptions;
- (NSDictionary *)sourceDescription;
- (void)setSourceDescription:(NSDictionary *)sourceDescription;

- (NSArray *)destinationDescriptions;
- (NSDictionary *)destinationDescription;
- (void)setDestinationDescription:(NSDictionary *)destinationDescription;

// Listening to sysex messages

- (void)listenForOneMessage;
- (void)listenForMultipleMessages;
- (void)cancelMessageListen;
- (void)doneWithMultipleMessageListen;

- (void)getMessageCount:(unsigned int *)messageCountPtr bytesRead:(unsigned int *)bytesReadPtr totalBytesRead:(unsigned int *)totalBytesReadPtr;

// Sending sysex messages

- (void)sendMessage;
- (unsigned int)bytesSent;
- (void)cancelSendingMessage;

@end
