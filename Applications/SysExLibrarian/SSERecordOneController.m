#import "SSERecordOneController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSEMainWindowController.h"
#import "SSEMIDIController.h"


@interface SSERecordOneController (Private)

- (void)readStatusChanged:(NSNotification *)notification;
- (void)readFinished:(NSNotification *)notification;

- (void)updateIndicators;
- (void)updateIndicatorsWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;

- (void)observeMIDIController;
- (void)stopObservingMIDIController;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSERecordOneController

- (id)initWithMainWindowController:(SSEMainWindowController *)mainWindowController midiController:(SSEMIDIController *)midiController;
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;
    nonretainedMIDIController = midiController;

    if (![NSBundle loadNibNamed:@"RecordOne" owner:self]) {
        [self release];
        return nil;
    }
    
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // TODO do we need to dealloc top-level items in the nib, like the window?
    
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

    [NSApp beginSheet:recordSheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];

    [self observeMIDIController];
    [nonretainedMIDIController listenForOneMessage];    
}

//
// Actions
//

- (IBAction)cancelRecordSheet:(id)sender;
{
    [nonretainedMIDIController cancelMessageListen];
    [self stopObservingMIDIController];

    [NSApp endSheet:recordSheetWindow];
}

@end

@implementation SSERecordOneController (Private)

- (void)readStatusChanged:(NSNotification *)notification;
{
    if (!progressUpdateEvent)
        progressUpdateEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(updateIndicators) onObject:self afterTime:[recordProgressIndicator animationDelay]] retain];
}

- (void)readFinished:(NSNotification *)notification;
{
    // If there is an update pending, try to cancel it. If that succeeds, then we know the event never happened, and we do it ourself now.
    if (progressUpdateEvent && [[OFScheduler mainScheduler] abortEvent:progressUpdateEvent])
        [progressUpdateEvent invoke];

    // Close the sheet, after a little bit of a delay (makes it look nicer)
    [NSApp performSelector:@selector(endSheet:) withObject:recordSheetWindow afterDelay:0.5];

    [self stopObservingMIDIController];

    [nonretainedMainWindowController addReadMessagesToLibrary];
}

- (void)updateIndicators;
{
    unsigned int messageCount, bytesRead, totalBytesRead;

    [nonretainedMIDIController getMessageCount:&messageCount bytesRead:&bytesRead totalBytesRead:&totalBytesRead];

    [self updateIndicatorsWithMessageCount:messageCount bytesRead:bytesRead totalBytesRead:totalBytesRead];

    [progressUpdateEvent release];
    progressUpdateEvent = nil;
}

- (void)updateIndicatorsWithMessageCount:(unsigned int)messageCount bytesRead:(unsigned int)bytesRead totalBytesRead:(unsigned int)totalBytesRead;
{
    if ((bytesRead == 0 && messageCount == 0)) {
        [recordProgressMessageField setStringValue:@"Waiting for SysEx message..."];
        [recordProgressBytesField setStringValue:@""];
    } else {
        [recordProgressIndicator animate:nil];
        [recordProgressMessageField setStringValue:@"Receiving SysEx message..."];
        [recordProgressBytesField setStringValue:[NSString abbreviatedStringForBytes:bytesRead + totalBytesRead]];
    }
}

- (void)observeMIDIController;
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readStatusChanged:) name:SSEMIDIControllerReadStatusChangedNotification object:nonretainedMIDIController];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readFinished:) name:SSEMIDIControllerReadFinishedNotification object:nonretainedMIDIController];
}

- (void)stopObservingMIDIController;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SSEMIDIControllerReadStatusChangedNotification object:nonretainedMIDIController];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SSEMIDIControllerReadFinishedNotification object:nonretainedMIDIController];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    // We don't really care how this sheet ended
    [sheet orderOut:nil];
}

@end
