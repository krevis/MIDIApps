#import "SSEWindowController.h"

@interface SSESysExSpeedWindowController : SSEWindowController
{
    IBOutlet NSTableView *tableView;

    NSArray *externalDevices;
}

+ (SSESysExSpeedWindowController *)sysExSpeedWindowController;

- (id)init;

@end
