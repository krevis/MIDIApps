#import "SSELibrary.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSELibraryEntry.h"
#import "BDAlias.h"
#import "NSWorkspace-Extensions.h"


@interface SSELibrary (Private)

- (NSArray *)_fileTypesFromDocumentTypeDictionary:(NSDictionary *)documentTypeDict;

- (NSDictionary *)_entriesByFilePath;

@end


@implementation SSELibrary

DEFINE_NSSTRING(SSELibraryDidChangeNotification);

const FourCharCode SSEApplicationCreatorCode = 'SnSX';
const FourCharCode SSELibraryFileTypeCode = 'sXLb';
const FourCharCode SSESysExFileTypeCode = 'sysX';
NSString *SSESysExFileExtension = @"syx";


+ (NSString *)defaultPath;
{
    return [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"SysEx Library"] stringByAppendingPathComponent:@"Library.sXLb"];
}

+ (NSString *)defaultFileDirectoryPath;
{
    return [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"SysEx Library"] stringByAppendingPathComponent:@"Files"];
}

- (id)init;
{
    NSArray *documentTypes;

    if (![super init])
        return nil;

    documentTypes = [[[self bundle] infoDictionary] objectForKey:@"CFBundleDocumentTypes"];
    if ([documentTypes count] > 0) {
        NSDictionary *documentTypeDict;

        documentTypeDict = [documentTypes objectAtIndex:0];
        rawSysExFileTypes = [[self _fileTypesFromDocumentTypeDictionary:documentTypeDict] retain];

        if ([documentTypes count] > 1) {
            documentTypeDict = [documentTypes objectAtIndex:1];
            standardMIDIFileTypes = [[self _fileTypesFromDocumentTypeDictionary:documentTypeDict] retain];
        }
    }
    allowedFileTypes = [[rawSysExFileTypes arrayByAddingObjectsFromArray:standardMIDIFileTypes] retain];
    
    libraryFilePath = [[self path] retain];
    entries = [[NSMutableArray alloc] init];
    flags.isDirty = NO;

    return self;
}

- (void)dealloc;
{
    [libraryFilePath release];
    libraryFilePath = nil;
    [entries release];
    entries = nil;
    [rawSysExFileTypes release];
    rawSysExFileTypes = nil;
    [standardMIDIFileTypes release];
    standardMIDIFileTypes = nil;
    [allowedFileTypes release];
    allowedFileTypes = nil;
    
    [super dealloc];
}

- (NSString *)path;
{
    // TODO why do we have this method, but keep the libraryFilePath ivar too?
    
    NSData *aliasData;
    NSString *path = nil;

    // TODO define a string for this, and use OFPreference
    aliasData = [[NSUserDefaults standardUserDefaults] objectForKey:@"LibraryAlias"];
    if (aliasData) {
        BDAlias *alias;

        alias = [BDAlias aliasWithData:aliasData];
        path = [alias fullPath];
    }
    // TODO We don't save this alias in the user defaults yet, but we need to.

    if (!path)
        path = [[self class] defaultPath];

    // TODO It is sort of unclear that we want things to work this way in future. If we set a library path, we don't necessarily want to keep track of it with an alias only, since the alias will no longer resolve if the file gets removed.
    // (Is my assumption about this correct? yes--BDAlias will return nil, but the alias manager will in reality give us back an FSRef for a file which no longer exists, and return fnfErr.  So we might want to go down to alias manager level and do this ourself.)
    // (that is: if the file gets removed we should create a new one at the same place as it was, not at the default path)

    return path;
}

- (NSString *)fileDirectoryPath;
{
    NSData *aliasData;
    NSString *path = nil;

    // TODO define a string for this, and use OFPreference
    aliasData = [[NSUserDefaults standardUserDefaults] objectForKey:@"LibraryFileDirectoryAlias"];
    if (aliasData) {
        BDAlias *alias;

        alias = [BDAlias aliasWithData:aliasData];
        path = [alias fullPath];
    }
    // TODO We don't save this alias in the user defaults yet, but we need to.

    if (!path)
        path = [[self class] defaultFileDirectoryPath];

    return path;
}

- (BOOL)isPathInFileDirectory:(NSString *)path;
{
    return [path hasPrefix:[[self fileDirectoryPath] stringByAppendingString:@"/"]];
}

- (NSString *)loadEntriesReturningErrorMessage;
{
    BOOL isDirectory;
    NSDictionary *libraryDictionary = nil;
    NSArray *entryDicts;
    unsigned int entryDictIndex, entryDictCount;

    // We should only be called once at startup
    OBASSERT([entries count] == 0);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:libraryFilePath isDirectory:&isDirectory])
        return nil;	// Nothing to load

    if (isDirectory)
        return @"There is a folder where the file should be.";

    if (![[NSFileManager defaultManager] isReadableFileAtPath:libraryFilePath])
        return @"The file's permissions do not allow reading.";

    libraryDictionary = [NSDictionary dictionaryWithContentsOfFile:libraryFilePath];
    if (!libraryDictionary)
        return @"The file could not be read.";

    // Now we can actually use the contents of the file...
    entryDicts = [libraryDictionary objectForKey:@"Entries"];
    entryDictCount = [entryDicts count];
    for (entryDictIndex = 0; entryDictIndex < entryDictCount; entryDictIndex++) {
        NSDictionary *entryDict;
        SSELibraryEntry *entry;

        entryDict = [entryDicts objectAtIndex:entryDictIndex];
        entry = [[SSELibraryEntry alloc] initWithLibrary:self dictionary:entryDict];
        [entries addObject:entry];
        [entry release];
    }

    // Ignore any changes that came from reading entries
    flags.isDirty = NO;

    return nil;
}

- (NSArray *)entries;
{
    return entries;
}

- (SSELibraryEntry *)addEntryForFile:(NSString *)filePath;
{
    SSELibraryEntry *entry;
    BOOL wasDirty;

    // Setting the entry path and name will cause us to be notified of a change, and we'll autosave.
    // However, the add might not succeed--if it doesn't, make sure our dirty flag isn't set if it shouldn't be.

    wasDirty = flags.isDirty;

    entry = [[SSELibraryEntry alloc] initWithLibrary:self];
    [entry setPath:filePath];

    if ([[entry messages] count] > 0) {
        [entry setNameFromFile];
        [entries addObject:entry];
        [entry release];
    } else {
        [entry release];
        entry = nil;
        if (!wasDirty)
            flags.isDirty = NO;
    }
    
    return entry;
}

- (SSELibraryEntry *)addNewEntryWithData:(NSData *)sysexData;
{
    NSFileManager *fileManager;
    NSString *newFileName;
    NSString *newFilePath;
    NSDictionary *newFileAttributes;
    SSELibraryEntry *entry = nil;

    fileManager = [NSFileManager defaultManager];
    
    newFileName = @"Untitled";
    newFilePath = [[[self fileDirectoryPath] stringByAppendingPathComponent:newFileName] stringByAppendingPathExtension:SSESysExFileExtension];
    newFilePath = [fileManager uniqueFilenameFromName:newFilePath];

    [fileManager createPathToFile:newFilePath attributes:nil];
    // NOTE This will raise an NSGenericException if it fails

    newFileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedLong:SSESysExFileTypeCode], NSFileHFSTypeCode,
        [NSNumber numberWithUnsignedLong:SSEApplicationCreatorCode], NSFileHFSCreatorCode,
        [NSNumber numberWithBool:YES], NSFileExtensionHidden, nil];

    if ([fileManager atomicallyCreateFileAtPath:newFilePath contents:sysexData attributes:newFileAttributes]) {
        entry = [self addEntryForFile:newFilePath];
        // TODO This is somewhat inefficient since we will write out the file and then immediately read it in again to get the messages.
    } else {
        [NSException raise:NSGenericException format:@"Couldn't create the file %@", newFilePath];
    }

    OBASSERT(entry != nil);

    return entry;
}

- (void)removeEntry:(SSELibraryEntry *)entry;
{
    unsigned int entryIndex;

    entryIndex = [entries indexOfObjectIdenticalTo:entry];
    if (entryIndex != NSNotFound) {
        [entries removeObjectAtIndex:entryIndex];

        [self noteEntryChanged];
    }
}

- (void)removeEntries:(NSArray *)entriesToRemove;
{
    [entries removeIdenticalObjectsFromArray:entriesToRemove];
    [self noteEntryChanged];
}

- (void)noteEntryChanged;
{
    flags.isDirty = YES;
    [self autosave];
    
    [[NSNotificationQueue defaultQueue] enqueueNotificationName:SSELibraryDidChangeNotification object:self postingStyle:NSPostWhenIdle];
}

- (void)autosave;
{
    [self performSelector:@selector(save) withObject:nil afterDelay:0];
}

- (void)save;
{
    NSMutableDictionary *dictionary;
    NSMutableArray *entryDicts;
    unsigned int entryCount, entryIndex;
    NSFileManager *fileManager;
    NSDictionary *fileAttributes;
    
    if (!flags.isDirty)
        return;

    dictionary = [NSMutableDictionary dictionary];
    entryDicts = [NSMutableArray array];

    entryCount = [entries count];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        NSDictionary *entryDict;

        entryDict = [[entries objectAtIndex:entryIndex] dictionaryValues];
        if (entryDict)
            [entryDicts addObject:entryDict];
    }

    [dictionary setObject:entryDicts forKey:@"Entries"];

    fileManager = [NSFileManager defaultManager];
    
    NS_DURING {
        [fileManager createPathToFile:libraryFilePath attributes:nil];
    } NS_HANDLER {
        // TODO The above will raise if it fails. Need to tell the user in that case.
    } NS_ENDHANDLER;

    fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedLong:SSELibraryFileTypeCode], NSFileHFSTypeCode,
        [NSNumber numberWithUnsignedLong:SSEApplicationCreatorCode], NSFileHFSCreatorCode,
        [NSNumber numberWithBool:YES], NSFileExtensionHidden, nil];

    [fileManager atomicallyCreateFileAtPath:libraryFilePath contents:[dictionary xmlPropertyListData] attributes:fileAttributes];    
    // TODO Need to handle the case of the above failing, too
    
    flags.isDirty = NO;
}

- (NSArray *)allowedFileTypes;
{
    return allowedFileTypes;
}

- (SSELibraryFileType)typeOfFileAtPath:(NSString *)filePath;
{
    NSString *fileType;

    if (!filePath || [filePath length] == 0) {
        return SSELibraryFileTypeUnknown;
    }
    
    fileType = [filePath pathExtension];
    if (!fileType || [fileType length] == 0) {
        fileType = NSHFSTypeOfFile(filePath);
    }

    if ([rawSysExFileTypes indexOfObject:fileType] != NSNotFound) {
        return SSELibraryFileTypeRaw;
    } else if ([standardMIDIFileTypes indexOfObject:fileType] != NSNotFound) {
        return SSELibraryFileTypeStandardMIDI;
    } else {
        return SSELibraryFileTypeUnknown;
    }
}

- (NSArray *)findEntriesForFiles:(NSArray *)filePaths returningNonMatchingFiles:(NSArray **)nonMatchingFilePathsPtr;
{
    NSDictionary *entriesByFilePath;
    NSMutableArray *nonMatchingFilePaths;
    NSMutableArray *matchingEntries;
    unsigned int filePathIndex, filePathCount;

    entriesByFilePath = [self _entriesByFilePath];

    filePathCount = [filePaths count];
    nonMatchingFilePaths = [NSMutableArray arrayWithCapacity:filePathCount];
    matchingEntries = [NSMutableArray arrayWithCapacity:filePathCount];

    for (filePathIndex = 0; filePathIndex < filePathCount; filePathIndex++) {
        NSString *filePath;
        SSELibraryEntry *entry;

        filePath = [filePaths objectAtIndex:filePathIndex];

        entry = [entriesByFilePath objectForKey:filePath];
        if (entry)
            [matchingEntries addObject:entry];
        else
            [nonMatchingFilePaths addObject:filePath];
    }
        
    if (nonMatchingFilePathsPtr)
        *nonMatchingFilePathsPtr = nonMatchingFilePaths;

    return matchingEntries;
}

- (BOOL)moveFilesInLibraryDirectoryToTrashForEntries:(NSArray *)entriesToTrash;
{
    unsigned int entryCount, entryIndex;
    NSMutableArray *filesToTrash;

    entryCount = [entriesToTrash count];
    filesToTrash = [NSMutableArray arrayWithCapacity:entryCount];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        SSELibraryEntry *entry;

        entry = [entriesToTrash objectAtIndex:entryIndex];
        if ([entry isFileInLibraryFileDirectory])
            [filesToTrash addObject:[entry path]];
    }

    if ([filesToTrash count] > 0)
        return [[NSWorkspace sharedWorkspace] moveFilesToTrash:filesToTrash];
    else
        return YES;

    // NOTE We do the above because -[NSWorkspace performFileOperation:NSWorkspaceRecycleOperation] is broken.
    // It doesn't work if there is already a file in the Trash with this name, and it doesn't make the Finder update.    
}

@end


@implementation SSELibrary (Private)

- (NSArray *)_fileTypesFromDocumentTypeDictionary:(NSDictionary *)documentTypeDict;
{
    NSMutableArray *fileTypes;
    NSArray *extensions;
    NSArray *osTypes;

    fileTypes = [NSMutableArray array];

    extensions = [documentTypeDict objectForKey:@"CFBundleTypeExtensions"];
    if (extensions && [extensions isKindOfClass:[NSArray class]]) {
        [fileTypes addObjectsFromArray:extensions];
    }

    osTypes = [documentTypeDict objectForKey:@"CFBundleTypeOSTypes"];
    if (osTypes && [osTypes isKindOfClass:[NSArray class]]) {
        unsigned int osTypeIndex, osTypeCount;

        osTypeCount = [osTypes count];
        for (osTypeIndex = 0; osTypeIndex < osTypeCount; osTypeIndex++) {
            [fileTypes addObject:[NSString stringWithFormat:@"'%@'", [osTypes objectAtIndex:osTypeIndex]]];
        }
    }

    return fileTypes;
}

- (NSDictionary *)_entriesByFilePath;
{
    unsigned int entryIndex, entryCount;
    NSMutableDictionary *entriesByFilePath;

    entryCount = [entries count];
    entriesByFilePath = [NSMutableDictionary dictionaryWithCapacity:entryCount];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        SSELibraryEntry *entry;
        NSString *filePath;

        entry = [entries objectAtIndex:entryIndex];
        filePath = [entry path];
        if (filePath) {
            OBASSERT([entriesByFilePath objectForKey:filePath] == nil);
            [entriesByFilePath setObject:entry forKey:filePath];
        }
    }

    return entriesByFilePath;
}

@end
