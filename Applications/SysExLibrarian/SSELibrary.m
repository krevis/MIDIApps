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

- (void)addEntryForFile:(NSString *)filePath;
{
    SSELibraryEntry *entry;

    entry = [[SSELibraryEntry alloc] init];
    [entry setPath:filePath];
    [entries addObject:entry];
    [entry release];

    flags.isDirty = YES;
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
