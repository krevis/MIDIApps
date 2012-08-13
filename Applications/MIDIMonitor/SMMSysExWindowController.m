/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
    NSSavePanel* savePanel = [NSSavePanel savePanel];

    if ([savePanel respondsToSelector:@selector(beginSheetModalForWindow:completionHandler:)]) {
        [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
            [self savePanelDidEnd:savePanel returnCode:result contextInfo:NULL];
        }];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

        [savePanel beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
    
#pragma clang diagnostic pop
    }
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

        if (![dataToWrite writeToFile:[[sheet URL] path] atomically:YES]) {
            NSString *title, *text;

            title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", SMBundleForObject(self), "title of error alert sheet");
            text = NSLocalizedStringFromTableInBundle(@"The file could not be saved.", @"MIDIMonitor", SMBundleForObject(self), "message when writing sysex data to a file fails");

            NSBeginAlertSheet(title, nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"%@", text);
        }
    }
}

@end
