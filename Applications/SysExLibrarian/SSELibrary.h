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
+ (NSString *)defaultFileDirectoryPath;

- (NSString *)path;
- (NSString *)fileDirectoryPath;
- (BOOL)isPathInFileDirectory:(NSString *)path;

- (NSString *)loadEntriesReturningErrorMessage;
- (NSArray *)entries;

- (SSELibraryEntry *)addEntryForFile:(NSString *)filePath;
    // NOTE: This will return nil, and add no entry, if no messages are in the file
- (SSELibraryEntry *)addNewEntryWithData:(NSData *)sysexData;
    // NOTE: This method will raise an exception on failure

- (void)removeEntry:(SSELibraryEntry *)entry;
- (void)removeEntries:(NSArray *)entriesToRemove;

- (void)noteEntryChanged;
- (void)autosave;
- (void)save;

- (NSArray *)allowedFileTypes;
- (SSELibraryFileType)typeOfFileAtPath:(NSString *)filePath;

- (NSArray *)findEntriesForFiles:(NSArray *)filePaths returningNonMatchingFiles:(NSArray **)nonMatchingFilePathsPtr;

- (BOOL)moveFilesInLibraryDirectoryToTrashForEntries:(NSArray *)entriesToTrash;

@end

// Notifications
extern NSString *SSELibraryDidChangeNotification;
