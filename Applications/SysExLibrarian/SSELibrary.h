#import <Cocoa/Cocoa.h>

@class SSELibraryEntry;


@interface SSELibrary : NSObject
{
    NSString *libraryFilePath;
    NSMutableArray *entries;
}

+ (NSString *)defaultPath;
+ (NSString *)defaultFileDirectory;

- (NSArray *)entries;

@end
