#import "SSELibraryEntry.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "BDAlias.h"
#import "SSELibrary.h"


@implementation SSELibraryEntry

- (id)initWithLibrary:(SSELibrary *)library;
{
    if (![super init])
        return nil;

    nonretainedLibrary = library;
    
    return self;
}

- (id)init;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [name release];
    name = nil;
    [alias release];
    alias = nil;
    nonretainedLibrary = nil;
    
    [super dealloc];
}

- (NSDictionary *)dictionaryValues;
{
    NSMutableDictionary *dict;

    dict = [NSMutableDictionary dictionary];
    if (alias)
        [dict setObject:[alias aliasData] forKey:@"alias"];
    if (name)
        [dict setObject:name forKey:@"name"];

    return dict;
}

- (void)takeValuesFromDictionary:(NSDictionary *)dict;
{
    id data, string;

    data = [dict objectForKey:@"alias"];
    if (data && [data isKindOfClass:[NSData class]])  {
        [alias release];
        alias = [[BDAlias alloc] initWithData:data];
    }

    string = [dict objectForKey:@"name"];
    if (string && [string isKindOfClass:[NSString class]]) {
        [name release];
        name = [string retain];
    } else {
        [self setNameFromFile];
    }
}

- (NSString *)path;
{
    return [alias fullPath];
    // TODO this will return nil if the file can't be found.
    // users of this class will want to check that, and ask the user to find the file
}

- (void)setPath:(NSString *)value;
{
    NSString *path;

    path = [self path];
    if (value != path && ![value isEqualToString:path]) {
        [alias release];
        alias = [[BDAlias alloc] initWithPath:value];

        [nonretainedLibrary noteEntryChanged];
    }
}

- (NSString *)name;
{
    return name;
}

- (void)setName:(NSString *)value;
{
    // TODO should we also rename the file that the alias points to? I don't think so...
    if (name != value) {
        [name release];
        name = [value retain];

        [nonretainedLibrary noteEntryChanged];
    }
}

- (void)setNameFromFile;
{
    NSString *path;
    NSString *newName;

    if ((path = [self path]))
        newName = [[[NSFileManager defaultManager] displayNameAtPath:path] retain];

    if (!newName)
        newName = @"Unknown";
        // TODO localize

    [self setName:newName];
}

- (NSArray *)messages;
{
    NSString *path;
    NSString *extension;
    NSData *data;
    NSArray *messages;

    path = [self path];
    extension = [[path pathExtension] uppercaseString];
        // TODO we should also be checking file type, probably
    if ([extension isEqualToString:@"MID"] || [extension isEqualToString:@"MIDI"]) {
        messages = [SMSystemExclusiveMessage systemExclusiveMessagesInStandardMIDIFile:path];
    } else {
        data = [NSData dataWithContentsOfFile:path];
        messages = [SMSystemExclusiveMessage systemExclusiveMessagesInData:data];
    }

    return messages;
}

@end
