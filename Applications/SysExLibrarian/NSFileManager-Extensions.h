#import <Cocoa/Cocoa.h>


@interface NSFileManager (SSEExtensions)

- (void) SSE_createPathToFile:(NSString *)newFilePath attributes:(NSDictionary*)attributes;
    // Checks for existence of all directories in newFilePath (assuming the last component is a file name, not a directory).
    // newFilePath must be an absolute path.
    // If necessary, creates any which do not exist, using the given attributes.
    // Raises NSGenericException if anything fails.

- (NSString*) SSE_uniqueFilenameFromName: (NSString*) originalPath;

@end
