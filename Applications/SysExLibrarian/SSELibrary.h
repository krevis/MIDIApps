#import <Cocoa/Cocoa.h>

@class SSELibraryEntry;


@interface SSELibrary : NSObject
{
    NSString *libraryFilePath;
    NSMutableArray *entries;
    struct {
        unsigned int isDirty:1;
    } flags;
}

+ (NSString *)defaultPath;
+ (NSString *)defaultFileDirectory;

- (NSArray *)entries;

- (void)addEntryForFile:(NSString *)filePath;

@end
