/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>

@class SNDisclosableView;
@class SNDisclosureButton;
@class SMMSourcesOutlineView;


@interface SMMMonitorWindowController : NSWindowController <NSTableViewDataSource>
{
    // Sources controls
    IBOutlet SNDisclosureButton *sourcesDisclosureButton;
    IBOutlet SNDisclosableView *sourcesDisclosableView;
    IBOutlet SMMSourcesOutlineView *sourcesOutlineView;

    // Filter controls
    IBOutlet SNDisclosureButton *filterDisclosureButton;
    IBOutlet SNDisclosableView *filterDisclosableView;
    IBOutlet NSButton *voiceMessagesCheckBox;
    IBOutlet NSMatrix *voiceMessagesMatrix;
    IBOutlet NSButton *systemCommonCheckBox;
    IBOutlet NSMatrix *systemCommonMatrix;
    IBOutlet NSButton *realTimeCheckBox;
    IBOutlet NSMatrix *realTimeMatrix;
    IBOutlet NSButton *systemExclusiveCheckBox;
    IBOutlet NSButton *invalidCheckBox;
    IBOutlet NSMatrix *channelRadioButtons;
    IBOutlet NSTextField *oneChannelField;
    NSArray *filterCheckboxes;
    NSArray *filterMatrixCells;
    
    // Event controls
    IBOutlet NSTableView *messagesTableView;
    IBOutlet NSButton *clearButton;
    IBOutlet NSTextField *maxMessageCountField;
    IBOutlet NSProgressIndicator *sysExProgressIndicator;
    IBOutlet NSTextField *sysExProgressField;
    IBOutlet NSBox *sysExProgressBox;

    // Transient data
    unsigned int oneChannel;
    NSArray *groupedInputSources;
    NSArray *displayedMessages;
    BOOL sendWindowFrameChangesToDocument;
    BOOL messagesNeedScrollToBottom;
    NSDate *nextMessagesRefreshDate;
    NSTimer *nextMessagesRefreshTimer;
}

- (id)init;

// Actions
- (IBAction)clearMessages:(id)sender;
- (IBAction)setMaximumMessageCount:(id)sender;
- (IBAction)changeFilter:(id)sender;
- (IBAction)changeFilterFromMatrix:(id)sender;
- (IBAction)setChannelRadioButton:(id)sender;
- (IBAction)setChannel:(id)sender;
- (IBAction)toggleSourcesShown:(id)sender;
- (IBAction)toggleFilterShown:(id)sender;
- (IBAction)showDetailsOfSelectedMessages:(id)sender;
- (IBAction)copy:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following:

- (void)synchronizeMessagesWithScrollToBottom:(BOOL)shouldScrollToBottom;
- (void)synchronizeSources;
- (void)synchronizeSourcesShown;
- (void)synchronizeMaxMessageCount;
- (void)synchronizeFilterControls;
- (void)synchronizeFilterShown;

- (void)couldNotFindSourcesNamed:(NSArray *)sourceNames;

- (void)updateSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;
- (void)stopSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;

- (void)revealInputSources:(NSSet *)inputSources;

- (NSPoint)messagesScrollPoint;

- (void)setWindowStateFromDocument;

@end
