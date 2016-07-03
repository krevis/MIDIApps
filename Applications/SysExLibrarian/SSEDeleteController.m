/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEDeleteController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSEMainWindowController.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"

@interface SSEDeleteController (Private)

- (void)deleteWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)checkForFilesInLibraryDirectory;
- (void)deleteLibraryFilesWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)deleteEntriesMovingLibraryFilesToTrash:(BOOL)shouldMoveToTrash;

@end


@implementation SSEDeleteController

NSString *SSEShowWarningOnDeletePreferenceKey = @"SSEShowWarningOnDelete";


- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;

    if (![NSBundle loadNibNamed:@"Delete" owner:self]) {
        [self release];
        return nil;
    }
    
    return self;
}

- (void)dealloc;
{
    // Top-level nib objects
    [deleteWarningSheetWindow release];
    deleteWarningSheetWindow = nil;
    [deleteLibraryFilesWarningSheetWindow release];
    deleteLibraryFilesWarningSheetWindow = nil;
    
    [entriesToDelete release];
    entriesToDelete = nil;
    
    [super dealloc];
}

//
// API for main window controller
//

- (void)deleteEntries:(NSArray *)entries;
{
    if ([entries count] == 0)
        return;

    SMAssert(entriesToDelete == nil);
    entriesToDelete = [entries retain];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:SSEShowWarningOnDeletePreferenceKey]) {
        [doNotWarnOnDeleteAgainCheckbox setIntValue:0];
        [NSApp beginSheet:deleteWarningSheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(deleteWarningSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    } else {
        [self checkForFilesInLibraryDirectory];
    }
}

//
// Actions
//

- (IBAction)endSheetWithReturnCodeFromSenderTag:(id)sender;
{
    [NSApp endSheet:[[nonretainedMainWindowController window] attachedSheet] returnCode:[sender tag]];
}

@end


@implementation SSEDeleteController (Private)

- (void)deleteWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];
    
    if (returnCode == NSOKButton) {
        if ([doNotWarnOnDeleteAgainCheckbox intValue] == 1)
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SSEShowWarningOnDeletePreferenceKey];

        [self checkForFilesInLibraryDirectory];
    } else {
        // Cancelled
        [entriesToDelete release];
        entriesToDelete = nil;
    }
}

- (void)checkForFilesInLibraryDirectory;
{
    NSUInteger entryIndex;
    BOOL areAnyFilesInLibraryDirectory = NO;

    entryIndex = [entriesToDelete count];
    while (entryIndex--) {
        if ([[entriesToDelete objectAtIndex:entryIndex] isFileInLibraryFileDirectory]) {
            areAnyFilesInLibraryDirectory = YES;
            break;
        }
    }

    if (areAnyFilesInLibraryDirectory) {
        [NSApp beginSheet:deleteLibraryFilesWarningSheetWindow modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(deleteLibraryFilesWarningSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    } else {
        [self deleteEntriesMovingLibraryFilesToTrash:NO];
    }
}

- (void)deleteLibraryFilesWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];

    if (returnCode == NSAlertDefaultReturn) {
        // "Yes" button
        [self deleteEntriesMovingLibraryFilesToTrash:YES];
    } else if (returnCode == NSAlertAlternateReturn) {
        // "No" button
        [self deleteEntriesMovingLibraryFilesToTrash:NO];
    } else {
        // "Cancel" button
        [entriesToDelete release];
        entriesToDelete = nil;
    }
}

- (void)deleteEntriesMovingLibraryFilesToTrash:(BOOL)shouldMoveToTrash;
{
    SSELibrary *library;

    library = [[entriesToDelete objectAtIndex:0] library];

    if (shouldMoveToTrash)
        [library moveFilesInLibraryDirectoryToTrashForEntries:entriesToDelete];
    [library removeEntries:entriesToDelete];

    [entriesToDelete release];
    entriesToDelete = nil;
    
    [nonretainedMainWindowController synchronizeInterface];
}

@end
