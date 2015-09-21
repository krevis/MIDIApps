/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEExportController.h"
#import "SSEMainWindowController.h"
#import <SnoizeMIDI/SnoizeMIDI.h>


#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_3

@interface NSSavePanel (DeclarationFor10_2)

// Declare this method so we can at least compile against 10.2 as a target
// (we check for it at runtime anyway so we're safe)
- (void)setAllowsOtherFileTypes:(BOOL)flag;

@end

#endif


@interface SSEExportController (Private)

- (void)saveSheetDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSEExportController

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController;
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;

    return self;
}

- (void)exportMessages:(NSArray *)messages fromFileName:(NSString*)fileName asSMF: (BOOL)asSMF
{
    [messages retain];
    exportingAsSMF = asSMF;

    // Pick a file name to export to.
    NSString *extension = asSMF ? @"mid" : @"syx";
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:extension]];
    [savePanel setCanSelectHiddenExtension: YES];
    [savePanel setAllowsOtherFileTypes: YES];

    NSString *defaultFileName;
    if (fileName) {
        defaultFileName = [fileName stringByDeletingPathExtension];
    } else {
        defaultFileName = NSLocalizedStringFromTableInBundle(@"SysEx", @"SysExLibrarian", SMBundleForObject(self), "default file name for exported standard MIDI file (w/o extension)");
    }
    defaultFileName = [defaultFileName stringByAppendingPathExtension:extension];
    
    [savePanel setNameFieldStringValue:defaultFileName];
    [savePanel beginSheetModalForWindow:[nonretainedMainWindowController window] completionHandler:^(NSInteger result) {
        [self saveSheetDidEnd:savePanel returnCode:result contextInfo:messages];
    }];
}

@end


@implementation SSEExportController (Private)

- (void)saveSheetDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSArray *messages = (NSArray *)contextInfo;

    if (returnCode == NSOKButton) {
        NSString *path;
        BOOL success;

        path = [[sheet URL] path];
        
        if (exportingAsSMF) {
            success = [SMSystemExclusiveMessage writeSystemExclusiveMessages:messages toStandardMIDIFile:path];
        } else {
            success = [[SMSystemExclusiveMessage dataForSystemExclusiveMessages: messages] writeToFile:path atomically:YES];
        }

        if (!success) {
            NSString *title, *message;

            title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
            message = NSLocalizedStringFromTableInBundle(@"The file could not be saved.",  @"SysExLibrarian", SMBundleForObject(self), "message if sysex can't be exported");
            
            NSRunAlertPanel(title, @"%@", nil, nil, nil, message);
        }
    }

    [messages release];
}

@end
