#import <Cocoa/Cocoa.h>

@class SSEMainWindowController;


@interface SSEExportController : NSObject
{
    SSEMainWindowController *nonretainedMainWindowController;

}

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController;

// Main window controller sends this to export messages
- (void)exportMessages:(NSArray *)messages;

@end
