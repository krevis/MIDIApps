#import <Cocoa/Cocoa.h>
#import "SSEWindowController.h"

@class SSELibraryEntry;


@interface SSEDetailsWindowController : SSEWindowController
{
    IBOutlet NSTableView *messagesTableView;
    IBOutlet NSTextView *textView;

    SSELibraryEntry *entry;

    NSArray *cachedMessages;
}

+ (SSEDetailsWindowController *)detailsWindowControllerWithEntry:(SSELibraryEntry *)inEntry;

- (id)initWithEntry:(SSELibraryEntry *)inEntry;

- (SSELibraryEntry *)entry;

@end
