#import "SSELibraryEntry.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "BDAlias.h"
#import "SSELibrary.h"


@interface SSELibraryEntry (Private)

- (void)_updateDerivedInformationFromMessages:(NSArray *)messages;

- (void)_updateManufacturerNameFromMessages:(NSArray *)messages;
- (void)_updateSizeFromMessages:(NSArray *)messages;
- (void)_updateMessageCountFromMessages:(NSArray *)messages;

@end


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

    [self updateDerivedInformation];

    if (manufacturerName)
        [dict setObject:manufacturerName forKey:@"manufacturerName"];
    if (sizeNumber)
        [dict setObject:sizeNumber forKey:@"size"];
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
    // TODO should we also rename the file that the alias points to? maybe...
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
        newName = [[NSFileManager defaultManager] displayNameAtPath:path];

    if (!newName)
        newName = @"Unknown";
        // TODO localize

    [self setName:newName];
}

- (NSArray *)messages;
{
    NSString *path;
    SSELibraryFileType fileType;
    NSArray *messages;

    path = [self path];
    fileType = [nonretainedLibrary typeOfFileAtPath:path];

    if (fileType == SSELibraryFileTypeStandardMIDI) {
        messages = [SMSystemExclusiveMessage systemExclusiveMessagesInStandardMIDIFile:path];
    } else if (fileType == SSELibraryFileTypeRaw) {
        NSData *data;

        if ((data = [NSData dataWithContentsOfFile:path]))
            messages = [SMSystemExclusiveMessage systemExclusiveMessagesInData:data];
    }

    // Always update this stuff when we read the messages
    [self _updateDerivedInformationFromMessages:messages];
    
    return messages;
}

- (void)updateDerivedInformation;
{
    [self _updateDerivedInformationFromMessages:[self messages]];
}

- (NSString *)manufacturerName;
{
    return manufacturerName;
}

- (unsigned int)size;
{
    return [sizeNumber unsignedIntValue];
}

- (unsigned int)messageCount;
{
    return [messageCountNumber unsignedIntValue];
}

@end


@implementation SSELibraryEntry (Private)

- (void)_updateDerivedInformationFromMessages:(NSArray *)messages;
{
    [self _updateManufacturerNameFromMessages:messages];
    [self _updateSizeFromMessages:messages];
    [self _updateMessageCountFromMessages:messages];
}

- (void)_updateManufacturerNameFromMessages:(NSArray *)messages;
{
    unsigned int messageIndex;

    [manufacturerName release];
    manufacturerName = nil;

    messageIndex = [messages count];
    while (messageIndex--) {
        NSString *messageManufacturerName;

        messageManufacturerName = [[messages objectAtIndex:messageIndex] manufacturerName];
        if (!messageManufacturerName)
            continue;

        if (!manufacturerName) {
            manufacturerName = messageManufacturerName;
        } else if (![messageManufacturerName isEqualToString:manufacturerName]) {
            manufacturerName = @"Various";
            // TODO localize
            break;
        }
    }

    if (!manufacturerName)
        manufacturerName = @"Unknown";	// TODO localize or get from SnoizeMIDI framework

    [manufacturerName retain];
}

- (void)_updateSizeFromMessages:(NSArray *)messages;
{
    unsigned int messageIndex;
    unsigned int size = 0;

    messageIndex = [messages count];
    while (messageIndex--)
        size += [[messages objectAtIndex:messageIndex] fullMessageDataLength];

    [sizeNumber release];
    sizeNumber = [[NSNumber alloc] initWithUnsignedInt:size];
}

- (void)_updateMessageCountFromMessages:(NSArray *)messages;
{
    [messageCountNumber release];
    messageCountNumber = [[NSNumber alloc] initWithUnsignedInt:[messages count]];
}

@end
