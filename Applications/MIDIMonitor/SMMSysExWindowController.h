#import <Cocoa/Cocoa.h>
#import "SMMWindowController.h"

@class SMSystemExclusiveMessage;


@interface SMMSysExWindowController : SMMWindowController
{
    IBOutlet NSTextField *timeField;
    IBOutlet NSTextField *manufacturerNameField;
    IBOutlet NSTextField *sizeField;    
    IBOutlet NSTextView *textView;

    SMSystemExclusiveMessage *message;
}

+ (SMMSysExWindowController *)sysExWindowControllerWithMessage:(SMSystemExclusiveMessage *)inMessage;

- (id)initWithMessage:(SMSystemExclusiveMessage *)inMessage;

- (SMSystemExclusiveMessage *)message;

- (IBAction)save:(id)sender;

@end

// Preferences keys
extern NSString *SMMSaveSysExWithEOXAlwaysPreferenceKey;
