#import "SSELibraryEntry.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "BDAlias.h"
#import "SSELibrary.h"


@implementation SSELibraryEntry

+ (SSELibraryEntry *)libraryEntryFromDictionary:(NSDictionary *)dict;
{
    SSELibraryEntry *entry;

    entry = [[[self alloc] init] autorelease];
    [entry takeValuesFromDictionary:dict];

    return entry;
}

- (id)init;
{
    if (![super init])
        return nil;

    return self;
}

- (void)dealloc
{
    [alias release];
    
    [super dealloc];
}

- (NSDictionary *)dictionaryValues;
{
    if (alias)
        return [NSDictionary dictionaryWithObject:[alias aliasData] forKey:@"alias"];
    else
        return nil;
}

- (void)takeValuesFromDictionary:(NSDictionary *)dict;
{
    NSData *data;

    data = [dict objectForKey:@"alias"];
    if (data && [data isKindOfClass:[NSData class]])  {
        [alias release];
        alias = [[BDAlias alloc] initWithData:data];
    }
}

- (NSString *)path;
{
    return [alias fullPath];
}

- (void)setPath:(NSString *)value;
{
    [alias release];
    alias = [[BDAlias alloc] initWithPath:value];
}

- (NSString *)name;
{
    // TODO should this be stored in the entry, perhaps?
    return [[NSFileManager defaultManager] displayNameAtPath:[self path]];
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
