#import <Cocoa/Cocoa.h>


@interface NSWorkspace (SSEExtensions)

- (BOOL)moveFilesToTrash:(NSArray *)filePaths;
    // Send an AppleEvent to the Finder to move the files to the Trash.
    // This is a workaround for bugs in -[NSWorkspace performFileOperation:NSWorkspaceRecycleOperation ...].

@end
