#import "NSFileManager-Extensions.h"


@implementation NSFileManager (SSEExtensions)

- (void) SSE_createPathToFile:(NSString *)newFilePath attributes:(NSDictionary*)attributes
{
    if (!newFilePath || [newFilePath length] == 0 || ![newFilePath isAbsolutePath]) {
        [NSException raise: NSGenericException format: @"Cannot create path to invalid file: '%@'.", newFilePath]; 
    }
    
    // Standardize the path and follow symlinks, so we won't hit any symlinks later on
    newFilePath = [[newFilePath stringByStandardizingPath] stringByResolvingSymlinksInPath];

    if (!newFilePath || [newFilePath length] == 0 || ![newFilePath isAbsolutePath]) {
        [NSException raise: NSGenericException format: @"Cannot create path to invalid file: '%@'.", newFilePath]; 
    }
    
    NSArray* components = [newFilePath pathComponents];
    unsigned int componentCount = [components count];
    
    if (componentCount <= 1) {
        [NSException raise: NSGenericException format: @"Cannot create path to invalid file: '%@'", newFilePath]; 
    }

    unsigned int componentIndex;
    NSString* partialPath = @"";
    NSString* failureReason = nil;
    for (componentIndex = 0; !failureReason && componentIndex < componentCount - 1; componentIndex++) {
        partialPath = [partialPath stringByAppendingPathComponent: [components objectAtIndex: componentIndex]];
        
        BOOL isDirectory;
        if ([self fileExistsAtPath: partialPath isDirectory: &isDirectory]) {
            if (isDirectory) {
                // OK, no problem, go on to the next component
            } else {
                // File already exists there, and isn't a symlink...
                failureReason = [NSString stringWithFormat: @"Cannot create path to file '%@' because an ordinary file already exists at '%@'.", newFilePath, partialPath];
            }            
        } else {
            // directory doesn't exist; try to create
            if (![self createDirectoryAtPath: partialPath attributes: attributes]) {
                failureReason = [NSString stringWithFormat: @"Cannot create path to file '%@' because the directory '%@' could not be created.", newFilePath, partialPath];
            }
        }
    }
        
    if (failureReason) {
        [NSException raise: NSGenericException format: @"%@", failureReason];
    }
}

- (NSString*) SSE_uniqueFilenameFromName: (NSString*) originalPath
{
    NSString* originalPathWithoutExtension = [originalPath stringByDeletingPathExtension];
    NSString* originalPathExtension = [originalPath pathExtension];

    NSString* testPath = originalPath;
    unsigned int suffix = 0;
    
    while ([self fileExistsAtPath: testPath])
    {
        suffix++;
        testPath = [[originalPathWithoutExtension stringByAppendingFormat: @"-%u", suffix] stringByAppendingPathExtension: originalPathExtension];
    }
    
    return testPath;
}

@end
