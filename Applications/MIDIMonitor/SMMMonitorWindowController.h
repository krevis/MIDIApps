#import <Cocoa/Cocoa.h>

@class OFScheduledEvent;
@class SNDisclosableView;
@class SNDisclosureButton;
@class SMMSourcesOutlineView;


@interface SMMMonitorWindowController : NSWindowController
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
    NSDate *nextSysExAnimateDate;
    BOOL messagesNeedScrollToBottom;
    NSDate *nextMessagesRefreshDate;
    OFScheduledEvent *nextMessagesRefreshEvent;
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

@end
