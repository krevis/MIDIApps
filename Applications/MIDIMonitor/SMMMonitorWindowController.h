#import <Cocoa/Cocoa.h>

@class SMMDisclosableView;


@interface SMMMonitorWindowController : NSWindowController
{
    IBOutlet NSPopUpButton *sourcePopUpButton;
    IBOutlet NSOutlineView *messagesOutlineView;
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
    NSArray *displayedMessages;
    NSMapTable *sysExRowsMapTable;
    BOOL sendWindowFrameChangesToDocument;
    NSDate *nextSysExAnimateDate;
}

- (id)init;

// Actions
- (IBAction)selectSource:(id)sender;
- (IBAction)clearMessages:(id)sender;
- (IBAction)setMaximumMessageCount:(id)sender;
- (IBAction)changeFilter:(id)sender;
- (IBAction)changeFilterFromMatrix:(id)sender;
- (IBAction)setChannelRadioButton:(id)sender;
- (IBAction)setChannel:(id)sender;
- (IBAction)toggleFilterShown:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeMessages;
- (void)synchronizeSources;
- (void)synchronizeMaxMessageCount;
- (void)synchronizeFilterControls;
- (void)synchronizeFilterShown;

- (void)scrollToLastMessage;

- (void)couldNotFindSourceNamed:(NSString *)sourceName;

- (void)updateSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;
- (void)stopSysExReadIndicatorWithBytes:(NSNumber *)bytesReadNumber;

@end
