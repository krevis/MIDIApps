#import "SSELibrary.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSELibraryEntry.h"


@interface SSELibrary (Private)

- (NSArray *)_fileTypesFromDocumentTypeDictionary:(NSDictionary *)documentTypeDict;

- (void)_loadEntries;

@end


@implementation SSELibrary


+ (NSString *)defaultPath;
{
    return [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"SysEx Librarian"] stringByAppendingPathComponent:@"SysEx Library.plist"];
}

+ (NSString *)defaultFileDirectory;
{
    return [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"SysEx Librarian"] stringByAppendingPathComponent:@"SysEx Files"];
}


- (id)init;
{
    NSArray *documentTypes;

    if (![super init])
        return nil;

    libraryFilePath = [[[self class] defaultPath] retain];
    entries = [[NSMutableArray alloc] init];
    flags.isDirty = NO;

    [self _loadEntries];

    // Ignore any changes that came from reading entries
    flags.isDirty = NO;

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
    
    [super dealloc];
}

- (NSArray *)entries;
{
    return entries;
}

- (SSELibraryEntry *)addEntryForFile:(NSString *)filePath;
{
    SSELibraryEntry *entry;

    entry = [[SSELibraryEntry alloc] initWithLibrary:self];
    [entry setPath:filePath];
    [entry setNameFromFile];
    [entries addObject:entry];
    [entry release];

    // Setting the entry path and name will cause us to be notified of a change, and we'll autosave.
    
    return entry;
}

- (SSELibraryEntry *)addNewEntryWithData:(NSData *)sysexData;
{
    NSString *newFilePath;
    SSELibraryEntry *entry = nil;

    // TODO what name?  attach the date, perhaps?
    // TODO also get the file directory for real, not the default
    newFilePath = [[SSELibrary defaultFileDirectory] stringByAppendingPathComponent:@"New SysEx File.syx"];
    newFilePath = [[NSFileManager defaultManager] uniqueFilenameFromName:newFilePath];

    // TODO maybe need to create the path to this file
    // TODO should maybe also hide the extension on this file
    
    if ([sysexData writeToFile:newFilePath atomically:YES])
        entry = [self addEntryForFile:newFilePath];

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

- (void)noteEntryChanged;
{
    flags.isDirty = YES;
    [self autosave];
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

    [dictionary writeToFile:libraryFilePath atomically:YES];
    
    flags.isDirty = NO;
}

- (NSArray *)rawSysExFileTypes;
{
    return rawSysExFileTypes;
}

- (NSArray *)standardMIDIFileTypes;
{
    return standardMIDIFileTypes;
}

- (NSArray *)allowedFileTypes;
{
    return [rawSysExFileTypes arrayByAddingObjectsFromArray:standardMIDIFileTypes];
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

- (void)_loadEntries;
{
    NSDictionary *libraryDictionary = nil;
    NSArray *entryDicts;
    unsigned int entryDictIndex, entryDictCount;

    NS_DURING {
        libraryDictionary = [NSDictionary dictionaryWithContentsOfFile:libraryFilePath];
    } NS_HANDLER {
        NSLog(@"Error loading library file \"%@\" : %@", libraryFilePath, localException);
        // TODO we can of course do better than this
    } NS_ENDHANDLER;

    entryDicts = [libraryDictionary objectForKey:@"Entries"];
    entryDictCount = [entryDicts count];
    for (entryDictIndex = 0; entryDictIndex < entryDictCount; entryDictIndex++) {
        NSDictionary *entryDict;
        SSELibraryEntry *entry;

        entryDict = [entryDicts objectAtIndex:entryDictIndex];
        entry = [[SSELibraryEntry alloc] initWithLibrary:self];
        [entry takeValuesFromDictionary:entryDict];
        [entries addObject:entry];
        [entry release];
    }
}

@end
