#import <Cocoa/Cocoa.h>

@class SMSystemExclusiveMessage;


@interface SMMSysExWindowController : NSWindowController
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

