#import "SSELibrary.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SSELibraryEntry.h"


@interface SSELibrary (Private)

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
    if (![super init])
        return nil;

    libraryFilePath = [[[self class] defaultPath] retain];
    entries = [[NSMutableArray alloc] init];
    flags.isDirty = NO;

    [self _loadEntries];
    
    return self;
}

- (void)dealloc;
{
    [libraryFilePath release];
    libraryFilePath = nil;
    [entries release];
    entries = nil;

    [super dealloc];
}

- (NSArray *)entries;
{
    return entries;
}

- (SSELibraryEntry *)addEntryForFile:(NSString *)filePath;
{
    SSELibraryEntry *entry;

    entry = [[SSELibraryEntry alloc] init];
    [entry setPath:filePath];
    [entries addObject:entry];
    [entry release];

    flags.isDirty = YES;
    [self autosave];

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

@end


@implementation SSELibrary (Private)

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
        if ((entry = [SSELibraryEntry libraryEntryFromDictionary:entryDict]))
            [entries addObject:entry];
    }
}

@end
