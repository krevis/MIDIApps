#import "SSERecordController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSEMainWindowController.h"
#import "SSEMIDIController.h"


@interface SSERecordController (Private)

- (void)readStatusChanged:(NSNotification *)notification;

- (void)updateIndicators;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSERecordController

- (id)initWithMainWindowController:(SSEMainWindowController *)mainWindowController midiController:(SSEMIDIController *)midiController;
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;
    nonretainedMIDIController = midiController;

    if (![NSBundle loadNibNamed:[self nibName] owner:self]) {
        [self release];
        return nil;
    }
    
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Top-level nib objects
    [sheetWindow release];
    sheetWindow = nil;
    
    [progressUpdateEvent release];
    progressUpdateEvent = nil;
    
    [super dealloc];
}

//
// API for main window controller
//

- (void)beginRecording;
{
    [self updateIndicatorsWithMessageCount:0 bytesRead:0 totalBytesRead:0];

    [NSApp beginSheet:sheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];

    [self observeMIDIController];

    [self tellMIDIControllerToStartRecording];
}

//
// Actions
//

- (IBAction)cancelRecording:(id)sender;
{
    [nonretainedMIDIController cancelMessageListen];
    [self stopObservingMIDIController];

    [NSApp endSheet:sheetWindow];
}

//
// To be implemented in subclasses
//

- (NSString *)nibName;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)tellMIDIControllerToStartRecording;
{
    OBRequestConcreteImplementation(self, _cmd);
}

- (void)updateIndicatorsWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    OBRequestConcreteImplementation(self, _cmd);
}

//
// May be overridden by subclasses
//

- (void)observeMIDIController;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readStatusChanged:) name:SSEMIDIControllerReadStatusChangedNotification object:nonretainedMIDIController];
}

- (void)stopObservingMIDIController;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SSEMIDIControllerReadStatusChangedNotification object:nonretainedMIDIController];
}

//
// To be used by subclasses
//

- (NSString *)waitingForSysexMessage;
{
    static NSString *waitingForSysexString = nil;

    if (!waitingForSysexString)
        waitingForSysexString = [NSLocalizedStringFromTableInBundle(@"Waiting for SysEx message...", @"SysExLibrarian", [self bundle], "message when waiting for sysex") retain];

    return waitingForSysexString;    
}

- (NSString *)receivingSysexMessage;
{
    static NSString *receivingSysexString = nil;

    if (!receivingSysexString)
        receivingSysexString = [NSLocalizedStringFromTableInBundle(@"Receiving SysEx message...", @"SysExLibrarian", [self bundle], "message when receiving sysex") retain];
    
    return receivingSysexString;
}

@end


@implementation SSERecordController (Private)

- (void)readStatusChanged:(NSNotification *)notification;
{
    if (!progressUpdateEvent)
        progressUpdateEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(updateIndicators) onObject:self afterTime:[progressIndicator animationDelay]] retain];
}

- (void)updateIndicators;
{
    unsigned int messageCount, bytesRead, totalBytesRead;

    [nonretainedMIDIController getMessageCount:&messageCount bytesRead:&bytesRead totalBytesRead:&totalBytesRead];

    [self updateIndicatorsWithMessageCount:messageCount bytesRead:bytesRead totalBytesRead:totalBytesRead];

    [progressUpdateEvent release];
    progressUpdateEvent = nil;
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // We don't really care how this sheet ended
    [sheet orderOut:nil];
}

@end
