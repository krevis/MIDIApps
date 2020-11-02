/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEMainWindowController.h"

#import <objc/objc-runtime.h>
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "NSPopUpButton-Extensions.h"
#import "SSEDeleteController.h"
#import "SSEDetailsWindowController.h"
#import "SSEExportController.h"
#import "SSEFindMissingController.h"
#import "SSEImportController.h"
#import "SSELibrary.h"
#import "SSELibraryEntry.h"
#import "SSEMIDIController.h"
#import "SSEPlayController.h"
#import "SSEPreferencesWindowController.h"
#import "SSERecordOneController.h"
#import "SSERecordManyController.h"
#import "SSETableView.h"


@interface SSEMainWindowController (Private)

- (void)displayPreferencesDidChange:(NSNotification *)notification;
- (void)listenForProgramChangesDidChange:(NSNotification *)notification;
- (void)programChangeBaseIndexDidChange:(NSNotification *)notification;
- (void)updateProgramChangeTableColumnFormatter;

- (BOOL)finishEditingResultsInError;

- (void)synchronizeDestinationPopUpWithDestinationGroups:(NSArray *)groupedDestinations currentDestination:(id <SSEOutputStreamDestination>)currentDestination;
- (void)synchronizeDestinationToolbarMenuWithDestinationGroups:(NSArray *)groupedDestinations currentDestination:(id <SSEOutputStreamDestination>)currentDestination;
- (NSString *)titleForDestination:(id <SSEOutputStreamDestination>)destination;

- (void)libraryDidChange:(NSNotification *)notification;
- (void)sortLibraryEntries;

- (void)scrollToEntries:(NSArray *)entries;

- (void)playSelectedEntries;
- (void)showDetailsOfSelectedEntries;
- (void)exportSelectedEntriesAsSMF;
- (void)exportSelectedEntriesAsSYX;
- (void)exportSelectedEntriesAsSMFOrSYX: (BOOL) asSMF;

- (void)openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (BOOL)areAnyFilesAcceptableForImport:(NSArray *)filePaths;

- (void)findMissingFilesAndPerformSelector:(SEL)selector;

@end


@implementation SSEMainWindowController

NSString *SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey = @"SSEAbbreviateFileSizesInLibraryTableView";

static SSEMainWindowController *controller = nil;


+ (SSEMainWindowController *)mainWindowController;
{
    if (!controller)
        controller = [[self alloc] init];

    return controller;
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"MainWindow"]))
        return nil;

    library = [[SSELibrary sharedLibrary] retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryDidChange:) name:SSELibraryDidChangeNotification object:library];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayPreferencesDidChange:) name:SSEDisplayPreferenceChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(listenForProgramChangesDidChange:) name:SSEListenForProgramChangesPreferenceChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(programChangeBaseIndexDidChange:) name:SSEProgramChangeBaseIndexPreferenceChangedNotification object:nil];

    sortColumnIdentifier = @"name";
    isSortAscending = YES;

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [midiController release];
    midiController = nil;    
    [playController release];
    playController = nil;
    [recordOneController  release];
    recordOneController = nil;
    [recordManyController release];
    recordManyController = nil;
    [deleteController release];
    deleteController = nil;
    [importController release];
    importController = nil;
    [exportController release];
    exportController= nil;
    [sortColumnIdentifier release];
    sortColumnIdentifier = nil;
    [sortedLibraryEntries release];
    sortedLibraryEntries = nil;
    [programChangeTableColumn release];
    programChangeTableColumn = nil;
    
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    [[self window] setShowsToolbarButton: NO];
    
    [libraryTableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    [libraryTableView setTarget:self];
    [libraryTableView setDoubleAction:@selector(play:)];
    
    // fix cells so they don't draw their own background (overdrawing the alternating row colors)
    NSEnumerator* oe = [[libraryTableView tableColumns] objectEnumerator];
    NSTableColumn* column;
    while ((column = [oe nextObject])) {
        [[column dataCell] setDrawsBackground: NO];
    }

    // The MIDI controller may cause us to do some things to the UI, so we create it now instead of earlier
    midiController = [[SSEMIDIController alloc] initWithWindowController:self];
	
    [programChangeTableColumn retain];  // extra retain in case we remove it from the table view
    [self updateProgramChangeTableColumnFormatter];
	[self listenForProgramChangesDidChange:nil];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self synchronizeInterface];
}

- (void)speciallyInitializeToolbarItem:(NSToolbarItem *)toolbarItem;
{
    float height;
    NSString *menuTitle;
    NSMenuItem *menuItem;
    NSMenu *submenu;

    nonretainedDestinationToolbarItem = toolbarItem;
    
    [toolbarItem setView:destinationPopUpButton];

    height = NSHeight([destinationPopUpButton frame]);
    [toolbarItem setMinSize:NSMakeSize(150, height)];
    [toolbarItem setMaxSize:NSMakeSize(1000, height)];

    menuTitle = NSLocalizedStringFromTableInBundle(@"Destination", @"SysExLibrarian", SMBundleForObject(self), "title of destination toolbar item");
    menuItem = [[NSMenuItem alloc] initWithTitle:menuTitle action:NULL keyEquivalent:@""];
    submenu = [[NSMenu alloc] initWithTitle:@""];
    [menuItem setSubmenu:submenu];
    [submenu release];
    [toolbarItem setMenuFormRepresentation:menuItem];
    [menuItem release];
}

//
// Action validation
//

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)theItem;
{
    SEL action;

    action = [theItem action];

    if (action == @selector(play:))
        return ([libraryTableView numberOfSelectedRows] > 0);
    else if (action == @selector(delete:))
        return ([libraryTableView numberOfSelectedRows] > 0);
    else if (action == @selector(showFileInFinder:))
        return ([libraryTableView numberOfSelectedRows] == 1 && [[[self selectedEntries] objectAtIndex:0] isFilePresent]);
    else if (action == @selector(rename:))
        return ([libraryTableView numberOfSelectedRows] == 1 && [[[self selectedEntries] objectAtIndex:0] isFilePresent]);
    else if (action == @selector(changeProgramNumber:))
        return ([libraryTableView numberOfSelectedRows] == 1 && [programChangeTableColumn tableView] != nil);
    else if (action == @selector(showDetails:))
        return ([libraryTableView numberOfSelectedRows] > 0);
    else if (action == @selector(saveAsStandardMIDI:) ||
             action == @selector(saveAsSysex:))
        return ([libraryTableView numberOfSelectedRows] > 0);
    else
        return [super validateUserInterfaceItem:theItem];
}

//
// Actions
//

- (IBAction)selectDestinationFromPopUpButton:(id)sender;
{
    [midiController setSelectedDestination:[(NSMenuItem *)[sender selectedItem] representedObject]];
}

- (IBAction)selectDestinationFromMenuItem:(id)sender;
{
    [midiController setSelectedDestination:[(NSMenuItem *)sender representedObject]];
}

- (IBAction)selectAll:(id)sender;
{
    // Forward to the library table view, even if it isn't the first responder
    [libraryTableView selectAll:sender];
}

- (IBAction)addToLibrary:(id)sender;
{
    if ([self finishEditingResultsInError])
        return;
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setAllowedFileTypes:[library allowedFileTypes]];
    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        [self openPanelDidEnd:openPanel returnCode:result contextInfo:NULL];
    }];
}

- (IBAction)delete:(id)sender;
{
    if ([self finishEditingResultsInError])
        return;

    if (!deleteController)
        deleteController = [[SSEDeleteController alloc] initWithWindowController:self];

    [deleteController deleteEntries:[self selectedEntries]];
}

- (IBAction)recordOne:(id)sender;
{
    if ([self finishEditingResultsInError])
        return;

    if (!recordOneController)
        recordOneController = [[SSERecordOneController alloc] initWithMainWindowController:self midiController:midiController];

    [recordOneController beginRecording];    
}

- (IBAction)recordMany:(id)sender;
{
    if ([self finishEditingResultsInError])
        return;

    if (!recordManyController)
        recordManyController = [[SSERecordManyController alloc] initWithMainWindowController:self midiController:midiController];

    [recordManyController beginRecording];
}

- (IBAction)play:(id)sender;
{
    if ([self finishEditingResultsInError])
        return;

    [self findMissingFilesAndPerformSelector:@selector(playSelectedEntries)];
}

- (IBAction)showFileInFinder:(id)sender;
{
    NSArray *selectedEntries;
    NSString *path;

    [self finishEditingInWindow];
        // We don't care if there is an error, go on anyway

    selectedEntries = [self selectedEntries];
    SMAssert([selectedEntries count] == 1);

    if ((path = [[selectedEntries objectAtIndex:0] path]))
        [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
    else
        NSBeep();	// Turns out the file isn't there after all
}

- (IBAction)rename:(id)sender;
{
    NSInteger columnIndex = [libraryTableView columnWithIdentifier:@"name"];

    if ([libraryTableView editedRow] >= 0 && [libraryTableView editedColumn] == columnIndex) {
        // We are already editing the name column of the table view, so don't do anything
    } else  {
        [self finishEditingInWindow];  // In case we are editing something else

        // Make sure that the file really exists right now before we try to rename it
        if ([[[self selectedEntries] objectAtIndex:0] isFilePresentIgnoringCachedValue]) {
            [libraryTableView editColumn:columnIndex row:[libraryTableView selectedRow] withEvent:nil select:YES];
        } else {
            NSBeep();
        }
    }
}

- (IBAction)changeProgramNumber:(id)sender
{
    NSInteger columnIndex = [libraryTableView columnWithIdentifier:@"programNumber"];

    if ([libraryTableView editedRow] >= 0 && [libraryTableView editedColumn] == columnIndex) {
        // We are already editing the program# column of the table view, so don't do anything
    } else  {
        [self finishEditingInWindow];  // In case we are editing something else
		
        [libraryTableView editColumn:columnIndex row:[libraryTableView selectedRow] withEvent:nil select:YES];
    }
}

- (IBAction)showDetails:(id)sender;
{
    if ([self finishEditingResultsInError])
        return;

    [self findMissingFilesAndPerformSelector:@selector(showDetailsOfSelectedEntries)];
}

- (IBAction)saveAsStandardMIDI:(id)sender;
{
    if ([self finishEditingResultsInError])
        return;

    [self findMissingFilesAndPerformSelector:@selector(exportSelectedEntriesAsSMF)];
}

- (IBAction)saveAsSysex:(id)sender;
{
    if ([self finishEditingResultsInError])
        return;
    
    [self findMissingFilesAndPerformSelector:@selector(exportSelectedEntriesAsSYX)];
}


//
// Other API
//

- (void)synchronizeInterface;
{
    [self synchronizeDestinations];
    [self synchronizeLibrarySortIndicator];
    [self synchronizeLibrary];
}

- (void)synchronizeDestinations;
{
    NSMutableArray *groupedDestinations;
    NSUInteger groupIndex;
    id <SSEOutputStreamDestination> currentDestination;

    // Remove empty groups from groupedDestinations
    groupedDestinations = [NSMutableArray arrayWithArray:[midiController groupedDestinations]];
    groupIndex = [groupedDestinations count];
    while (groupIndex--) {
        if ([[groupedDestinations objectAtIndex:groupIndex] count] == 0)
            [groupedDestinations removeObjectAtIndex:groupIndex];
    }

    currentDestination = [midiController selectedDestination];

    [self synchronizeDestinationPopUpWithDestinationGroups:groupedDestinations currentDestination:currentDestination];
    [self synchronizeDestinationToolbarMenuWithDestinationGroups:groupedDestinations currentDestination:currentDestination];
}

- (void)synchronizeLibrarySortIndicator;
{
    NSTableColumn *column;

    column = [libraryTableView tableColumnWithIdentifier:sortColumnIdentifier];    
    [libraryTableView setSortColumn:column isAscending:isSortAscending];
    [libraryTableView setHighlightedTableColumn:column];
}

- (void)synchronizeLibrary;
{
    NSArray *selectedEntries;

    selectedEntries = [self selectedEntries];

    [self sortLibraryEntries];

    // NOTE Some entries in selectedEntries may no longer be present in sortedLibraryEntries.
    // We don't need to manually take them out of selectedEntries because selectEntries can deal with
    // entries that are missing.
    
    [libraryTableView reloadData];
    [self selectEntries:selectedEntries];

    // Sometimes, apparently, reloading the table view will not mark the window as needing update. Weird.
    [NSApp setWindowsNeedUpdate:YES];
}

- (void)importFiles:(NSArray *)filePaths showingProgress:(BOOL)showProgress;
{
    if (!importController)
        importController = [[SSEImportController alloc] initWithWindowController:self library:library];

    [importController importFiles:filePaths showingProgress:showProgress];
}

- (void)showNewEntries:(NSArray *)newEntries;
{
    [self synchronizeLibrary];
    [self selectEntries:newEntries];
    [self scrollToEntries:newEntries];
}

- (void)addReadMessagesToLibrary;
{
    NSData *allSysexData;
    SSELibraryEntry *entry = nil;

    allSysexData = [SMSystemExclusiveMessage dataForSystemExclusiveMessages:[midiController messages]];
    if (!allSysexData)
        return;	// No messages, no data, nothing to do
    
    NSError *error = nil;
    entry = [library addNewEntryWithData:allSysexData error:&error];

    if (entry) {
        [self showNewEntries:[NSArray arrayWithObject:entry]];
    } else {
        // We need to get rid of the sheet right away, instead of after the delay (see -[SSERecordOneController readFinished]).
        NSWindow *attachedSheet =  [[self window] attachedSheet];
        if (attachedSheet) {
            [NSObject cancelPreviousPerformRequestsWithTarget:NSApp selector:@selector(endSheet:) object:attachedSheet];
            [NSApp endSheet:attachedSheet];
        }

        // Now we can start another sheet.
        SMAssert([[self window] attachedSheet] == nil);
        
        NSString *title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
        NSString *message = NSLocalizedStringFromTableInBundle(@"The file could not be created.\n%@", @"SysExLibrarian", SMBundleForObject(self), "message of alert when recording to a new file fails");

        NSBeginAlertSheet(title, nil, nil, nil, [self window], nil, NULL, NULL, NULL, message, error.localizedDescription ?: @"");
    }
}

- (void)playEntryWithProgramNumber:(Byte)desiredProgramNumber
{
	if (!playController)
		playController = [[SSEPlayController alloc] initWithWindowController:self midiController:midiController];
	
    NSEnumerator* oe = [sortedLibraryEntries objectEnumerator];
	SSELibraryEntry *entry;
    while ((entry = [oe nextObject])) {
        NSNumber* programNumber = [entry programNumber];
        if (programNumber && [programNumber unsignedIntValue] == desiredProgramNumber) {
			[playController playMessagesInEntryForProgramChange:entry];
			return;
        }
	}
}

- (NSArray *)selectedEntries;
{
    NSMutableArray *selectedEntries = [NSMutableArray array];
    
    NSIndexSet* selectedRowIndexes = [libraryTableView selectedRowIndexes];
    NSUInteger row;
    for (row = [selectedRowIndexes firstIndex]; row != NSNotFound; row = [selectedRowIndexes indexGreaterThanIndex:row]) {
        [selectedEntries addObject:[sortedLibraryEntries objectAtIndex:row]];
    }
    
    return selectedEntries;
}

- (void)selectEntries:(NSArray *)entries;
{
    NSUInteger entryCount, entryIndex;
    
    [libraryTableView deselectAll:nil];
    
    entryCount = [entries count];
    if (entryCount == 0)
        return;
    
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        NSUInteger row;
        
        row = [sortedLibraryEntries indexOfObjectIdenticalTo:[entries objectAtIndex:entryIndex]];
        if (row != NSNotFound)
            [libraryTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:YES];
    }
}

@end


@implementation SSEMainWindowController (NotificationsDelegatesDataSources)

//
// NSTableView data source
//

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [sortedLibraryEntries count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry;
    NSString *identifier;

    entry = [sortedLibraryEntries objectAtIndex:row];
    identifier = [tableColumn identifier];

    if ([identifier isEqualToString:@"name"]) {
        return [entry name];
    } else if ([identifier isEqualToString:@"manufacturer"]) {
        return [entry manufacturer];
    } else if ([identifier isEqualToString:@"size"]) {
        NSNumber *entrySize;

        entrySize = [entry size];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey])
            return [NSString SnoizeMIDI_abbreviatedStringForByteCount:[entrySize unsignedIntValue]];
        else
            return [entrySize stringValue];
    } else if ([identifier isEqualToString:@"messageCount"]) {
        return [entry messageCount];
	} else if ([identifier isEqualToString:@"programNumber"]) {
        NSNumber *programNumber = [entry programNumber];
        if (programNumber) {
            NSInteger offset = [[NSUserDefaults standardUserDefaults] integerForKey:SSEProgramChangeBaseIndexPreferenceKey];
            return @( [programNumber integerValue] + offset );
        }
        else {
            return nil;
        }
    } else {
        return nil;
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry = [sortedLibraryEntries objectAtIndex:row];

    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"name"]) {
        NSString *newName = (NSString *)object;

        if (!newName || [newName length] == 0)
            return;        
        
        if (![entry renameFileTo:newName]) {
            NSString *title, *message;
            
            title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
            message = NSLocalizedStringFromTableInBundle(@"The file for this item could not be renamed.", @"SysExLibrarian", SMBundleForObject(self), "message of alert when renaming a file fails");
            
            NSBeginAlertSheet(title, nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"%@", message);
        }
    } else if ([identifier isEqualToString:@"programNumber"]) {
        NSNumber* newProgramNumber = nil;
		if (object) {
            NSInteger intValue = [object integerValue];

            NSInteger baseIndex = [[NSUserDefaults standardUserDefaults] integerForKey:SSEProgramChangeBaseIndexPreferenceKey];
            intValue -= baseIndex;

            if (intValue >= 0 && intValue <= 127) {
                newProgramNumber = @(intValue);
            }
        }
        [entry setProgramNumber:newProgramNumber];
	}
    
    [self synchronizeLibrary];
}

//
// SSETableView data source
//

- (void)tableView:(SSETableView *)tableView deleteRows:(NSIndexSet *)rows;
{
    [self delete:tableView];
}

- (NSDragOperation)tableView:(SSETableView *)tableView draggingEntered:(id <NSDraggingInfo>)sender;
{
    if ([self areAnyFilesAcceptableForImport:[[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType]])
        return NSDragOperationGeneric;
    else
        return NSDragOperationNone;
}

- (BOOL)tableView:(SSETableView *)tableView performDragOperation:(id <NSDraggingInfo>)sender;
{
    NSArray *filePaths;

    filePaths = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    [self importFiles:filePaths showingProgress:YES];
    return YES;
}

//
// NSTableView delegate
//

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry;
    NSColor *color;
    
    entry = [sortedLibraryEntries objectAtIndex:row];
    if ([entry isFilePresent]) {
        if (@available(macOS 10.14, *)) {
            color = [NSColor labelColor];
        }
        else {
            color = [NSColor blackColor];
        }
    }
    else {
        if (@available(macOS 10.14, *)) {
            color = [NSColor systemRedColor];
        }
        else {
            color = [NSColor redColor];
        }
    }

    [cell setTextColor:color];
}

- (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn;
{
    NSString *identifier;

    identifier = [tableColumn identifier];
    if ([identifier isEqualToString:sortColumnIdentifier]) {
        isSortAscending = !isSortAscending;
    } else {
        [sortColumnIdentifier release];
        sortColumnIdentifier = [identifier retain];
        isSortAscending = YES;
    }

    [self synchronizeLibrarySortIndicator];
    [self synchronizeLibrary];
    [self scrollToEntries:[self selectedEntries]];
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    SSELibraryEntry *entry = [sortedLibraryEntries objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];

    if ([identifier isEqualToString:@"name"]) {
        return [entry isFilePresent];
    } else if ([identifier isEqualToString:@"programNumber"]) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)tableViewKeyDownReceivedSpace:(SSETableView *)tableView {
    // Space key is used as a shortcut for -play:
    [self play:nil];
    return YES;
}

@end


@implementation SSEMainWindowController (Private)

- (void)displayPreferencesDidChange:(NSNotification *)notification;
{
    [libraryTableView reloadData];
}

- (void)listenForProgramChangesDidChange:(NSNotification *)notification
{
    [self finishEditingInWindow];

    BOOL listening = [[NSUserDefaults standardUserDefaults] boolForKey:SSEListenForProgramChangesPreferenceKey];
    
    if (listening) {
        if (![programChangeTableColumn tableView]) {
            [libraryTableView addTableColumn:programChangeTableColumn];

            NSTableColumn* nameCol = [libraryTableView tableColumnWithIdentifier:@"name"];
            [nameCol setWidth:[nameCol width] - [programChangeTableColumn width] - 3];
        }
    } else {
        if ([programChangeTableColumn tableView]) {
            [libraryTableView removeTableColumn:programChangeTableColumn];
            
            NSTableColumn* nameCol = [libraryTableView tableColumnWithIdentifier:@"name"];
            [nameCol setWidth:[nameCol width] + [programChangeTableColumn width] + 3];
        }
    }
}

- (void)programChangeBaseIndexDidChange:(NSNotification *)notification
{
    [self updateProgramChangeTableColumnFormatter];
    [libraryTableView reloadData];
}

- (void)updateProgramChangeTableColumnFormatter
{
    NSNumberFormatter *formatter = ((NSCell *)programChangeTableColumn.dataCell).formatter;
    NSInteger baseIndex = [[NSUserDefaults standardUserDefaults] integerForKey:SSEProgramChangeBaseIndexPreferenceKey];
    formatter.minimum = @(baseIndex + 0  );
    formatter.maximum = @(baseIndex + 127);
}

- (BOOL)finishEditingResultsInError;
{
    [self finishEditingInWindow];
    return ([[self window] attachedSheet] != nil);
}

- (NSResponder *)firstResponderWhenNotEditing
{
    return libraryTableView;
}

//
// Destination selections (popup and toolbar menu)
//

- (void)synchronizeDestinationPopUpWithDestinationGroups:(NSArray *)groupedDestinations currentDestination:(id <SSEOutputStreamDestination>)currentDestination;
{
    BOOL wasAutodisplay;
    NSUInteger groupCount, groupIndex;
    BOOL found = NO;

    // The pop up button redraws whenever it's changed, so turn off autodisplay to stop the blinkiness
    wasAutodisplay = [[self window] isAutodisplay];
    [[self window] setAutodisplay:NO];

    [destinationPopUpButton removeAllItems];

    groupCount = [groupedDestinations count];
    for (groupIndex = 0; groupIndex < groupCount; groupIndex++) {
        NSArray *dests;
        NSUInteger destIndex, destCount;

        dests = [groupedDestinations objectAtIndex:groupIndex];
        destCount = [dests count];

        if (groupIndex > 0)
            [destinationPopUpButton SSE_addSeparatorItem];
        
        for (destIndex = 0; destIndex < destCount; destIndex++) {
            id <SSEOutputStreamDestination> destination;
            NSString *title;
    
            destination = [dests objectAtIndex:destIndex];            
            title = [self titleForDestination:destination];
            [destinationPopUpButton SSE_addItemWithTitle:title representedObject:destination];
    
            if (!found && (destination == currentDestination)) {
                [destinationPopUpButton selectItemAtIndex:[destinationPopUpButton numberOfItems] - 1];
                found = YES;
            }
        }
    }

    if (!found)
        [destinationPopUpButton selectItem:nil];

    // ...and turn autodisplay on again
    if (wasAutodisplay)
        [[self window] displayIfNeeded];
    [[self window] setAutodisplay:wasAutodisplay];
}

- (void)synchronizeDestinationToolbarMenuWithDestinationGroups:(NSArray *)groupedDestinations currentDestination:(id <SSEOutputStreamDestination>)currentDestination;
{
    // Set the title to "Destination: <Whatever>"
    // Then set up the submenu items
    NSMenuItem *topMenuItem;
    NSString *selectedDestinationTitle;
    NSString *topTitle;
    NSMenu *submenu;
    NSUInteger submenuIndex;
    NSUInteger groupCount, groupIndex;
    BOOL found = NO;
    
    topMenuItem = [nonretainedDestinationToolbarItem menuFormRepresentation];

    selectedDestinationTitle = [self titleForDestination:currentDestination];
    if (!selectedDestinationTitle)
        selectedDestinationTitle = NSLocalizedStringFromTableInBundle(@"None", @"SysExLibrarian", SMBundleForObject(self), "none");

    topTitle = [[NSLocalizedStringFromTableInBundle(@"Destination", @"SysExLibrarian", SMBundleForObject(self), "title of destination toolbar item") stringByAppendingString:@": "] stringByAppendingString:selectedDestinationTitle];
    [topMenuItem setTitle:topTitle];

    submenu = [topMenuItem submenu];
    submenuIndex = [submenu numberOfItems];
    while (submenuIndex--)
        [submenu removeItemAtIndex:submenuIndex];

    groupCount = [groupedDestinations count];
    for (groupIndex = 0; groupIndex < groupCount; groupIndex++) {
        NSArray *dests;
        NSUInteger destIndex, destCount;

        dests = [groupedDestinations objectAtIndex:groupIndex];
        destCount = [dests count];

        if (groupIndex > 0)
            [submenu addItem:[NSMenuItem separatorItem]];

        for (destIndex = 0; destIndex < destCount; destIndex++) {
            id <SSEOutputStreamDestination> destination;
            NSString *title;
            NSMenuItem *menuItem;

            destination = [dests objectAtIndex:destIndex];

            title = [self titleForDestination:destination];
            menuItem = [submenu addItemWithTitle:title action:@selector(selectDestinationFromMenuItem:) keyEquivalent:@""];
            [menuItem setRepresentedObject:destination];
            [menuItem setTarget:self];
    
            if (!found && (destination == currentDestination)) {
                [menuItem setState:NSOnState];
                found = YES;
            }
        }
    }        

    // Workaround to get the toolbar item to refresh after we change the title of the menu item
    [topMenuItem retain];
    [nonretainedDestinationToolbarItem setMenuFormRepresentation:nil];
    [nonretainedDestinationToolbarItem setMenuFormRepresentation:topMenuItem];
    [topMenuItem release];
}

- (NSString *)titleForDestination:(id <SSEOutputStreamDestination>)destination;
{
    NSString *title;
    NSArray *externalDeviceNames;

    title = [destination outputStreamDestinationName];
    externalDeviceNames = [destination outputStreamDestinationExternalDeviceNames];
    if ([externalDeviceNames count] > 0) {
        unichar emdashCharacter = 0x2014;
        NSString *emdashString = [NSString stringWithCharacters: &emdashCharacter length: 1];
        title = [[title stringByAppendingString:emdashString] stringByAppendingString:[externalDeviceNames componentsJoinedByString:@", "]];
    }

    return title;
}


//
// Library interaction
//

- (void)libraryDidChange:(NSNotification *)notification;
{
    // Reloading the table view will wipe out the edit session, so don't do that if we're editing
    if ([libraryTableView editedRow] == -1)
        [self synchronizeLibrary];
}

static NSInteger libraryEntryComparator(id object1, id object2, void *context)
{
    NSString *key = (NSString *)context;
    id value1, value2;

    value1 = [object1 valueForKey:key];
    value2 = [object2 valueForKey:key];

    if (value1 && value2) {
        return [value1 compare:value2];
    } else if (value1) {
        return NSOrderedDescending;
    } else {
        // both are nil
        return NSOrderedSame;
    }
}

- (void)sortLibraryEntries;
{
    [sortedLibraryEntries release];
    sortedLibraryEntries = [[library entries] sortedArrayUsingFunction:libraryEntryComparator context:sortColumnIdentifier];
    if (!isSortAscending)
        sortedLibraryEntries = [sortedLibraryEntries SnoizeMIDI_reversedArray];
    [sortedLibraryEntries retain];
}

- (void)scrollToEntries:(NSArray *)entries;
{
    NSUInteger entryCount, entryIndex;
    NSUInteger lowestRow = UINT_MAX;

    entryCount = [entries count];
    if (entryCount == 0)
        return;
    
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        NSUInteger row;

        row = [sortedLibraryEntries indexOfObjectIdenticalTo:[entries objectAtIndex:entryIndex]];
        if (row != NSNotFound)
            lowestRow = MIN(lowestRow, row);
    }

    [libraryTableView scrollRowToVisible:lowestRow];
}

//
// Doing things with selected entries
//

- (void)playSelectedEntries;
{
    NSArray *selectedEntries;
    NSMutableArray *messages;
    NSUInteger entryCount, entryIndex;

    selectedEntries = [self selectedEntries];

    messages = [NSMutableArray array];
    entryCount = [selectedEntries count];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        [messages addObjectsFromArray:[[selectedEntries objectAtIndex:entryIndex] messages]];
    }

    if ([messages count] > 0) {
        if (!playController)
            playController = [[SSEPlayController alloc] initWithWindowController:self midiController:midiController];

        [playController playMessages:messages];
    }
}

- (void)showDetailsOfSelectedEntries;
{
    NSArray *selectedEntries;
    NSUInteger entryCount, entryIndex;

    selectedEntries = [self selectedEntries];
    entryCount = [selectedEntries count];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        SSELibraryEntry *entry;

        entry = [selectedEntries objectAtIndex:entryIndex];
        [[SSEDetailsWindowController detailsWindowControllerWithEntry:entry] showWindow:nil];
    }
}

- (void)exportSelectedEntriesAsSMF
{
    [self exportSelectedEntriesAsSMFOrSYX: YES];
}

- (void)exportSelectedEntriesAsSYX
{
    [self exportSelectedEntriesAsSMFOrSYX: NO];
}

- (void)exportSelectedEntriesAsSMFOrSYX: (BOOL) asSMF
{
    NSArray *selectedEntries;
    NSMutableArray *messages;
    NSUInteger entryCount, entryIndex;
    NSString* fileName;

    selectedEntries = [self selectedEntries];

    messages = [NSMutableArray array];
    entryCount = [selectedEntries count];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        [messages addObjectsFromArray:[[selectedEntries objectAtIndex:entryIndex] messages]];
    }
    fileName = [[selectedEntries objectAtIndex: 0] name];

    if ([messages count] > 0) {
        if (!exportController)
            exportController = [[SSEExportController alloc] initWithWindowController:self];

        [exportController exportMessages:messages fromFileName:fileName asSMF: asSMF];
    }
}

//
// Add files / importing
//

- (void)openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void  *)contextInfo;
{
    if (returnCode == NSOKButton) {
        [openPanel orderOut:nil];
        
        NSArray* urls = [openPanel URLs];
        NSMutableArray* filenames = [NSMutableArray arrayWithCapacity:[urls count]];
        
        for (NSURL* url in urls) {
            NSString* path = [url path];
            if (path)
                [filenames addObject:path];
        }
        
        [self importFiles:filenames showingProgress:NO];
    }
}

- (BOOL)areAnyFilesAcceptableForImport:(NSArray *)filePaths;
{
    NSFileManager *fileManager;
    NSUInteger fileIndex, fileCount;

    fileManager = [NSFileManager defaultManager];

    fileCount = [filePaths count];
    for (fileIndex = 0; fileIndex < fileCount; fileIndex++) {
        NSString *filePath;
        BOOL isDirectory;

        filePath = [filePaths objectAtIndex:fileIndex];
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] == NO)
            continue;

        if (isDirectory)
            return YES;

        if ([fileManager isReadableFileAtPath:filePath] && [library typeOfFileAtPath:filePath] != SSELibraryFileTypeUnknown)
            return YES;
    }

    return NO;
}

//
// Finding missing files
//

- (void)findMissingFilesAndPerformSelector:(SEL)selector;
{
    NSArray *selectedEntries;
    NSUInteger entryCount, entryIndex;
    NSMutableArray *entriesWithMissingFiles;

    selectedEntries = [self selectedEntries];

    // Which entries can't find their associated file?
    entryCount = [selectedEntries count];
    entriesWithMissingFiles = [NSMutableArray arrayWithCapacity:entryCount];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        SSELibraryEntry *entry;

        entry = [selectedEntries objectAtIndex:entryIndex];
        if (![entry isFilePresentIgnoringCachedValue])
            [entriesWithMissingFiles addObject:entry];
    }

    if ([entriesWithMissingFiles count] == 0) {
        [self performSelector:selector];
    } else {
        if (!findMissingController)
            findMissingController = [[SSEFindMissingController alloc] initWithWindowController:self library:library];
    
        [findMissingController findMissingFilesForEntries:entriesWithMissingFiles andPerformSelectorOnWindowController:selector];
    }
}

@end
