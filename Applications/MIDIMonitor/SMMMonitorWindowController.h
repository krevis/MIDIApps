#import <Cocoa/Cocoa.h>

@class SMMDisclosableView;
@class SMMSourcesOutlineView;


@interface SMMMonitorWindowController : NSWindowController
{
    IBOutlet SMMSourcesOutlineView *sourcesOutlineView;
    IBOutlet NSTableView *messagesTableView;
    IBOutlet NSButton *clearButton;
    IBOutlet NSTextField *maxMessageCountField;
    IBOutlet NSProgressIndicator *sysExProgressIndicator;
    IBOutlet NSTextField *sysExProgressField;
    IBOutlet NSBox *sysExProgressBox;

    // Filter controls
    IBOutlet NSButton *filterDisclosureButton;
    IBOutlet SMMDisclosableView *filterDisclosableView;
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
    unsigned int oneChannel;

    // Transient data
    NSArray *groupedInputSources;
    NSArray *displayedMessages;
    BOOL sendWindowFrameChangesToDocument;
    NSDate *nextSysExAnimateDate;
}

- (id)init;

// Actions
- (IBAction)clearMessages:(id)sender;
- (IBAction)setMaximumMessageCount:(id)sender;
- (IBAction)changeFilter:(id)sender;
- (IBAction)changeFilterFromMatrix:(id)sender;
- (IBAction)setChannelRadioButton:(id)sender;
- (IBAction)setChannel:(id)sender;
- (IBAction)toggleFilterShown:(id)sender;
- (IBAction)showSelectedMessageDetails:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeMessages;
- (void)synchronizeSources;
- (void)synchronizeMaxMessageCount;
- (void)synchronizeFilterControls;
- (void)synchronizeFilterShown;

- (void)scrollToLastMessage;

- (void)couldNotFindSourcesNamed:(NSArray *)sourceNames;

- (void)updateSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;
- (void)stopSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;

@end
