#import <Cocoa/Cocoa.h>

@class SSELibraryEntry;


@interface SSELibrary : NSObject
{
    NSString *libraryFilePath;
    NSMutableArray *entries;
    struct {
        unsigned int isDirty:1;
    } flags;

    NSArray *rawSysExFileTypes;
    NSArray *standardMIDIFileTypes;
}

+ (NSString *)defaultPath;
+ (NSString *)defaultFileDirectory;

- (NSArray *)entries;

- (SSELibraryEntry *)addEntryForFile:(NSString *)filePath;
- (SSELibraryEntry *)addNewEntryWithData:(NSData *)sysexData;

- (void)removeEntry:(SSELibraryEntry *)entry;

- (void)noteEntryChanged;
- (void)autosave;
- (void)save;

- (NSArray *)rawSysExFileTypes;
- (NSArray *)standardMIDIFileTypes;
- (NSArray *)allowedFileTypes;

@end
