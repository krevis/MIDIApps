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
    nonretainedLibrary = nil;

    [name release];
    name = nil;
    [alias release];
    alias = nil;

    [messages release];
    messages = nil;
    [manufacturerName release];
    manufacturerName = nil;
    [sizeNumber release];
    sizeNumber = nil;
    [messageCountNumber release];
    messageCountNumber = nil;
    
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
    [self manufacturerName];
    if (manufacturerName)
        [dict setObject:manufacturerName forKey:@"manufacturerName"];
    [self size];
    if (sizeNumber)
        [dict setObject:sizeNumber forKey:@"size"];
    [self messageCount];
    if (messageCountNumber)
        [dict setObject:messageCountNumber forKey:@"messageCount"];

    return dict;
}

- (void)takeValuesFromDictionary:(NSDictionary *)dict;
{
    id data, string, number;

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

    string = [dict objectForKey:@"manufacturerName"];
    if (string && [string isKindOfClass:[NSString class]]) {
        [manufacturerName release];
        manufacturerName = [string retain];
    }

    number = [dict objectForKey:@"size"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        [sizeNumber release];
        sizeNumber = [number retain];
    }

    number = [dict objectForKey:@"messageCount"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        [messageCountNumber release];
        messageCountNumber = [number retain];
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
    // TODO should check that the file hasn't changed since we last read the messages
    if (!messages) {
        NSString *path;
        NSString *extension;
        NSData *data;

        path = [self path];
        extension = [[path pathExtension] uppercaseString];
            // TODO we should also be checking file type, probably
        if ([extension isEqualToString:@"MID"] || [extension isEqualToString:@"MIDI"]) {
            messages = [SMSystemExclusiveMessage systemExclusiveMessagesInStandardMIDIFile:path];
        } else {
            data = [NSData dataWithContentsOfFile:path];
            messages = [SMSystemExclusiveMessage systemExclusiveMessagesInData:data];
        }

        [messages retain];

        // Invalidate any cached information which may no longer be accurate
        [manufacturerName release];
        manufacturerName = nil;
        [sizeNumber release];
        sizeNumber = nil;
        [messageCountNumber release];
        messageCountNumber = nil;
    }

    return messages;
}

- (NSString *)manufacturerName;
{
    if (!manufacturerName) {
        NSArray *theMessages;
        unsigned int messageIndex;
            
        theMessages = [self messages];
        messageIndex = [theMessages count];
        while (messageIndex--) {
            NSString *thisManufacturerName;
    
            thisManufacturerName = [[theMessages objectAtIndex:messageIndex] manufacturerName];
            if (!thisManufacturerName)
                continue;
            
            if (!manufacturerName) {
                manufacturerName = thisManufacturerName;
            } else if (![thisManufacturerName isEqualToString:manufacturerName]) {
                manufacturerName = @"Various";
                // TODO localize
                break;
            }
        }
    
        if (!manufacturerName)
            manufacturerName = @"Unknown";	// TODO localize or get from SnoizeMIDI framework
    
        [manufacturerName retain];
    }

    return manufacturerName;
}

- (unsigned int)size;
{
    if (!sizeNumber) {
        NSArray *theMessages;
        unsigned int messageIndex;
        unsigned int size = 0;
    
        theMessages = [self messages];
        messageIndex = [theMessages count];
        while (messageIndex--) {
            size += [[theMessages objectAtIndex:messageIndex] fullMessageDataLength];
        }

        sizeNumber = [[NSNumber alloc] initWithUnsignedInt:size];
    }

    return [sizeNumber unsignedIntValue];
}

- (unsigned int)messageCount;
{
    if (!messageCountNumber) {
        messageCountNumber = [[NSNumber alloc] initWithUnsignedInt:[[self messages] count]];
    }

    return [messageCountNumber unsignedIntValue];
}

@end
