#import <Cocoa/Cocoa.h>


@interface NSWorkspace (SSEExtensions)

- (BOOL)moveFileToTrash:(NSString *)path;
    // Send an AppleEvent to the Finder to move the file to the Trash.
    // This is a workaround for bugs in -[NSWorkspace performFileOperation:NSWorkspaceRecycleOperation ...].

@end
