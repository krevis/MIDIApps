/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSEOutputStreamDestination.h"

@class SSEMainWindowController;
@class SSECombinationOutputStream;


typedef enum {
    SSEMIDIControllerIdle,
    SSEMIDIControllerSending,
    SSEMIDIControllerWillDelayBeforeNext,     
    SSEMIDIControllerDelayingBeforeNext,
    SSEMIDIControllerCancelled,
    SSEMIDIControllerFinishing
}   SSEMIDIControllerSendStatus;

@interface SSEMIDIController : NSObject <MessageDestination>
{
    SSEMainWindowController *nonretainedMainWindowController;

    // MIDI processing
    PortInputStream *inputStream;
	VirtualInputStream *virtualInputStream;
    SSECombinationOutputStream *outputStream;
        
    // Transient data
    NSMutableArray *messages;
    
    // ... for listening for sysex
    BOOL listeningToSysexMessages;
    BOOL listenToMultipleSysexMessages;
    NSUInteger messageBytesRead;
    NSUInteger totalBytesRead;

    // ... for sending sysex
    NSTimeInterval pauseTimeBetweenMessages;
    SysExSendRequest *nonretainedCurrentSendRequest;
    NSUInteger sendingMessageCount;
    NSUInteger sendingMessageIndex;
    NSUInteger bytesToSend;
    NSUInteger bytesSent;
    SSEMIDIControllerSendStatus sendStatus;
    BOOL scheduledUpdateSysExReadIndicator;
    
    // ... for listening to program change messages
    BOOL listeningToProgramChangeMessages;
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

- (void)getMessageCount:(NSUInteger *)messageCountPtr bytesRead:(NSUInteger *)bytesReadPtr totalBytesRead:(NSUInteger *)totalBytesReadPtr;

// Sending sysex messages

- (void)sendMessages;
- (void)cancelSendingMessages;

- (void)getMessageCount:(NSUInteger *)messageCountPtr messageIndex:(NSUInteger *)messageIndexPtr bytesToSend:(NSUInteger *)bytesToSendPtr bytesSent:(NSUInteger *)bytesSentPtr;

@end

// Preferences keys
extern NSString *SSESelectedDestinationPreferenceKey;
extern NSString *SSESysExReadTimeOutPreferenceKey;
extern NSString *SSESysExIntervalBetweenSentMessagesPreferenceKey;
extern NSString *SSEListenForProgramChangesPreferenceKey;
extern NSString *SSEInterruptOnProgramChangePreferenceKey;
extern NSString *SSEProgramChangeBaseIndexPreferenceKey;
extern NSString *SSECustomSysexBufferSizePreferenceKey;

// Notifications
extern NSString *SSEMIDIControllerReadStatusChangedNotification;
extern NSString *SSEMIDIControllerReadFinishedNotification;
extern NSString *SSEMIDIControllerSendWillStartNotification;
extern NSString *SSEMIDIControllerSendFinishedNotification;
    // userInfo has NSNumber for key "success" indicating if all messages were sent
extern NSString *SSEMIDIControllerSendFinishedImmediatelyNotification;
extern NSString *SSEProgramChangeBaseIndexPreferenceChangedNotification;
extern NSString *SSECustomSysexBufferSizePreferenceChangedNotification;
