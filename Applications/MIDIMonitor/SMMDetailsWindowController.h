#import <Cocoa/Cocoa.h>
#import "SMMWindowController.h"

@class SMMessage;


@interface SMMDetailsWindowController : SMMWindowController
{
    IBOutlet NSTextField *timeField;
    IBOutlet NSTextField *sizeField;    
    IBOutlet NSTextView *textView;

    SMMessage *message;
}

+ (BOOL)canShowDetailsForMessage:(SMMessage *)inMessage;

+ (SMMDetailsWindowController *)detailsWindowControllerWithMessage:(SMMessage *)inMessage;

- (id)initWithMessage:(SMMessage *)inMessage;

- (SMMessage *)message;

// To be overridden by subclasses

+ (NSString *)windowNibName;
- (NSData *)dataForDisplay;

@end
