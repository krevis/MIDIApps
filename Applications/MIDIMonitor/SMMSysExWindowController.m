#import "SMMSysExWindowController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>


@interface SMMSysExWindowController (Private)

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SMMSysExWindowController

NSString *SMMSaveSysExWithEOXAlwaysPreferenceKey = @"SMMSaveSysExWithEOXAlways";


+ (NSString*)windowNibName
{
    return @"SysEx";
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [manufacturerNameField setStringValue:[(SMSystemExclusiveMessage *)message manufacturerName]];
}

- (NSData *)dataForDisplay
{
    return [(SMSystemExclusiveMessage *)message receivedDataWithStartByte];
}

//
// Actions
//

- (IBAction)save:(id)sender;
{
    [[NSSavePanel savePanel] beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

@end


@implementation SMMSysExWindowController (Private)

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];

    if (returnCode == NSOKButton) {
        SMSystemExclusiveMessage *sysExMessage = (SMSystemExclusiveMessage *)message;
        NSData *dataToWrite;
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SMMSaveSysExWithEOXAlwaysPreferenceKey])
            dataToWrite = [sysExMessage fullMessageData];
        else
            dataToWrite = [sysExMessage receivedDataWithStartByte];

        if (![dataToWrite writeToFile:[sheet filename] atomically:YES]) {
            NSString *title, *text;

            title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", SMBundleForObject(self), "title of error alert sheet");
            text = NSLocalizedStringFromTableInBundle(@"The file could not be saved.", @"MIDIMonitor", SMBundleForObject(self), "message when writing sysex data to a file fails");

            NSBeginAlertSheet(title, nil, nil, nil, [self window], nil, NULL, NULL, NULL, text);
        }
    }
}

@end
