#import <Cocoa/Cocoa.h>


@interface NSWorkspace (SSEExtensions)

- (BOOL)SSE_moveFilesToTrash:(NSArray *)filePaths;
    // Move the specified files or folders to the Trash.
    // This is both a convenience method and a workaround for bugs in -[NSWorkspace performFileOperation:NSWorkspaceRecycleOperation ...].
    // (On Mac OS X 10.1.x and earlier, that method does not correctly handle the case when there
    // is already a file in the trash with the same name as a file being moved to the trash.
    // Also, it often does not cause the Dock icon of the Trash to update.)

@end
