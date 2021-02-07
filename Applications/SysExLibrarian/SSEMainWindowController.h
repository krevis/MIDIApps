/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEWindowController.h"

@class DeleteController;
@class ExportController;
@class FindMissingController;
@class SSEMIDIController;
@class SSELibrary;
@class SSEPlayController;
@class RecordController;
@class SSETableView;
@class SSELibraryEntry;
@class ImportController;

@interface SSEMainWindowController : SSEWindowController
{
    IBOutlet NSPopUpButton *destinationPopUpButton;
    IBOutlet SSETableView *libraryTableView;
	IBOutlet NSTableColumn *programChangeTableColumn;

    // Library
    SSELibrary *library;
    NSArray *sortedLibraryEntries;

    // Subcontrollers
    SSEMIDIController *midiController;
    SSEPlayController *playController;
    RecordController *recordOneController;
    RecordController *recordManyController;
    DeleteController *deleteController;
    ImportController *importController;
    ExportController *exportController;
    FindMissingController *findMissingController;
    
    // Transient data
    NSString *sortColumnIdentifier;
    BOOL isSortAscending;
    NSToolbarItem *nonretainedDestinationToolbarItem;
}

+ (SSEMainWindowController *)sharedInstance;

// Actions

- (IBAction)selectDestinationFromPopUpButton:(id)sender;
- (IBAction)selectDestinationFromMenuItem:(id)sender;

- (IBAction)selectAll:(id)sender;

- (IBAction)addToLibrary:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)recordOne:(id)sender;
- (IBAction)recordMany:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)showFileInFinder:(id)sender;
- (IBAction)rename:(id)sender;
- (IBAction)changeProgramNumber:(id)sender;
- (IBAction)showDetails:(id)sender;
- (IBAction)saveAsStandardMIDI:(id)sender;
- (IBAction)saveAsSysex:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeDestinations;
- (void)synchronizeLibrarySortIndicator;
- (void)synchronizeLibrary;

- (void)importFiles:(NSArray *)filePaths showingProgress:(BOOL)showProgress;
- (void)showNewEntries:(NSArray *)newEntries;

- (void)addReadMessagesToLibrary;

- (void)playEntryWithProgramNumber:(Byte)programNumber;

- (NSArray *)selectedEntries;
- (void)selectEntries:(NSArray *)entries;

@end

// Preferences keys
extern NSString *SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey;
