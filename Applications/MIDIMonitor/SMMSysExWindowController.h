#import <Cocoa/Cocoa.h>

@class SMSystemExclusiveMessage;


@interface SMMSysExWindowController : NSWindowController
{
    IBOutlet NSTextView *textView;

    SMSystemExclusiveMessage *message;
}

+ (SMMSysExWindowController *)sysExWindowControllerWithMessage:(SMSystemExclusiveMessage *)inMessage;

- (id)initWithMessage:(SMSystemExclusiveMessage *)inMessage;

- (SMSystemExclusiveMessage *)message;

@end
