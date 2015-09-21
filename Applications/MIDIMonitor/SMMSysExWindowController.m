/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMSysExWindowController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>

NSString* const SMMSaveSysExWithEOXAlwaysPreferenceKey = @"SMMSaveSysExWithEOXAlways";

@interface SMMSysExWindowController ()

@property (nonatomic, assign) IBOutlet NSTextField *manufacturerNameField;

@end

@implementation SMMSysExWindowController

+ (NSString*)windowNibName
{
    return @"SysEx";
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    self.manufacturerNameField.stringValue = ((SMSystemExclusiveMessage *)self.message).manufacturerName;
}

- (NSData *)dataForDisplay
{
    return ((SMSystemExclusiveMessage *)self.message).receivedDataWithStartByte;
}

//
// Actions
//

- (IBAction)save:(id)sender
{
    NSSavePanel* savePanel = [NSSavePanel savePanel];
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        [self savePanelDidEnd:savePanel returnCode:result contextInfo:NULL];
    }];
}

#pragma mark Private

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];

    if (returnCode == NSOKButton) {
        SMSystemExclusiveMessage *sysExMessage = (SMSystemExclusiveMessage *)self.message;
        NSData *dataToWrite = [[NSUserDefaults standardUserDefaults] boolForKey:SMMSaveSysExWithEOXAlwaysPreferenceKey] ? sysExMessage.fullMessageData : sysExMessage.receivedDataWithStartByte;

        if (![dataToWrite writeToFile:sheet.URL.path atomically:YES]) {
            NSString *title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", SMBundleForObject(self), "title of error alert sheet");
            NSString *text = NSLocalizedStringFromTableInBundle(@"The file could not be saved.", @"MIDIMonitor", SMBundleForObject(self), "message when writing sysex data to a file fails");

            NSBeginAlertSheet(title, nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"%@", text);
        }
    }
}

@end
