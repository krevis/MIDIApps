#import <Cocoa/Cocoa.h>
#import "SMMDetailsWindowController.h"

@class SMSystemExclusiveMessage;


@interface SMMSysExWindowController : SMMDetailsWindowController
{
    IBOutlet NSTextField *manufacturerNameField;
}

- (IBAction)save:(id)sender;

@end

// Preferences keys
extern NSString *SMMSaveSysExWithEOXAlwaysPreferenceKey;
