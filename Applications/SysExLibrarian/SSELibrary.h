#import <Cocoa/Cocoa.h>

@class SSELibraryEntry;


typedef enum _SSELibraryFileType {
    SSELibraryFileTypeRaw = 0,
    SSELibraryFileTypeStandardMIDI = 1,
    SSELibraryFileTypeUnknown = 2
} SSELibraryFileType;


@interface SSELibrary : NSObject
{
    NSString *libraryFilePath;
    NSMutableArray *entries;
    struct {
        unsigned int isDirty:1;
    } flags;

    NSArray *rawSysExFileTypes;
    NSArray *standardMIDIFileTypes;
    NSArray *allowedFileTypes;
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

- (NSArray *)allowedFileTypes;
- (SSELibraryFileType)typeOfFileAtPath:(NSString *)filePath;

@end
