#import "SSELibraryEntry.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "BDAlias.h"
#import "SSELibrary.h"


@interface SSELibraryEntry (Private)

+ (NSString *)manufacturerFromMessages:(NSArray *)messages;
+ (NSNumber *)sizeFromMessages:(NSArray *)messages;
+ (NSNumber *)messageCountFromMessages:(NSArray *)messages;

- (void)takeValuesFromDictionary:(NSDictionary *)dict;

- (void)updateDerivedInformationFromMessages:(NSArray *)messages;

- (void)setManufacturer:(NSString *)value;
- (void)setSize:(NSNumber *)value;
- (void)setMessageCount:(NSNumber *)value;

@end


@implementation SSELibraryEntry

DEFINE_NSSTRING(SSELibraryEntryNameDidChangeNotification);


- (id)initWithLibrary:(SSELibrary *)library;
{
    if (![super init])
        return nil;

    nonretainedLibrary = library;
    flags.hasLookedForFile = NO;
    flags.isFilePresent = NO;

    return self;
}

- (id)initWithLibrary:(SSELibrary *)library dictionary:(NSDictionary *)dict;
{
    if (![self initWithLibrary:library])
        return nil;

    [self takeValuesFromDictionary:dict];
    
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

    [manufacturer release];
    manufacturer = nil;
    [sizeNumber release];
    sizeNumber = nil;
    [messageCountNumber release];
    messageCountNumber = nil;
    
    [super dealloc];
}

- (SSELibrary *)library;
{
    return nonretainedLibrary;
}

- (NSDictionary *)dictionaryValues;
{
    NSMutableDictionary *dict;

    dict = [NSMutableDictionary dictionary];
    if (alias)
        [dict setObject:[alias aliasData] forKey:@"alias"];
    if (name)
        [dict setObject:name forKey:@"name"];

    if (manufacturer)
        [dict setObject:manufacturer forKey:@"manufacturerName"];
    if (sizeNumber)
        [dict setObject:sizeNumber forKey:@"size"];
    if (messageCountNumber)
        [dict setObject:messageCountNumber forKey:@"messageCount"];

    return dict;
}

- (NSString *)path;
{
    BOOL wasFilePresent;
    NSString *path;

    wasFilePresent = flags.hasLookedForFile && flags.isFilePresent;
    
    path = [alias fullPath];

    flags.hasLookedForFile = YES;
    flags.isFilePresent = (path && [[NSFileManager defaultManager] fileExistsAtPath:path]);

    if (flags.isFilePresent != wasFilePresent)
        [nonretainedLibrary noteEntryChanged];

    if (flags.isFilePresent)
        [self setName:[[NSFileManager defaultManager] displayNameAtPath:path]];

    return path;
}

- (void)setPath:(NSString *)value;
{
    [alias release];
    alias = [[BDAlias alloc] initWithPath:value];

    [nonretainedLibrary noteEntryChanged];
}

- (NSString *)name;
{
    return name;
}

- (void)setName:(NSString *)value;
{
    if (name != value && ![name isEqualToString:value]) {
        [name release];
        name = [value retain];

        [[NSNotificationCenter defaultCenter] postNotificationName:SSELibraryEntryNameDidChangeNotification object:self];
        [nonretainedLibrary noteEntryChanged];
    }
}

- (void)setNameFromFile;
{
    NSString *path;
    NSString *newName = nil;

    if ((path = [self path]))
        newName = [[NSFileManager defaultManager] displayNameAtPath:path];

    if (!newName)
        newName = @"Unknown";

    [self setName:newName];
}

- (BOOL)renameFileTo:(NSString *)newFileName;
{
    NSString *path;
    NSString *fileName;
    NSString *extension;
    NSString *modifiedNewFileName;
    NSString *newPath;
    BOOL shouldHideExtension = NO;
    BOOL shouldShowExtension = NO;
    NSFileManager *fileManager;
    BOOL success = NO;

    path = [self path];
    if (!path)
        return NO;

    fileName = [path lastPathComponent];
    extension = [fileName pathExtension];

    // Calculate the new file name, keeping the same extension as before.
    // TODO Is that really exactly what we want?
    if (extension && [extension length] > 0) {
        // The old file name had an extension. We need to make sure the new name has the same extension.
        NSString *newExtension;
        
        newExtension = [newFileName pathExtension];
        if (newExtension && [newExtension length] > 0) {
            // Both the old and new file names have extensions.
            if ([newExtension isEqualToString:extension]) {
                // The extensions are the same, so use the new name as it is.
                modifiedNewFileName = newFileName;
                // But show the extension, since the user explicitly stated it.
                shouldShowExtension = YES;
            } else {
                // The extensions are different. Just tack the old extension on to the new name.
                modifiedNewFileName = [newFileName stringByAppendingPathExtension:extension];
                // And make sure the extension is hidden in the filesystem.
                shouldHideExtension = YES;
                // TODO In this case, we really should ask the user if they really want to change the extension, or not,
                // and then do what they tell us.
            }
        } else {
            // The new file name has no extension, so add the old one on.
            modifiedNewFileName = [newFileName stringByAppendingPathExtension:extension];
            // We also want to hide the extension from the user, so it looks like the new name was granted.
            shouldHideExtension = YES;
        }
    } else {
        // The old file name had no extension, so just accept the new name as it is.
        modifiedNewFileName = newFileName;    
    }
    OBASSERT((shouldShowExtension && shouldHideExtension) == NO);    // We can't do both!

    // TODO We should do something like the code below (not sure if it's correct):
#if 0    
    // Limit new file name to 255 unicode characters, because that's all HFS+ will allow.
    // NOTE Yes, we should be taking into account the actual filesystem, which might not be HFS+.
    if ([modifiedNewFileName length] > 255) {
        NSString *withoutExtension;
        NSString *newExtension;

        withoutExtension = [modifiedNewFileName stringByDeletingPathExtension];
        newExtension =  [modifiedNewFileName pathExtension];
        withoutExtension = [withoutExtension substringToIndex:(255 - [newExtension length] - 1)];
        modifiedNewFileName = [withoutExtension stringByAppendingPathExtension:newExtension];        
    }
#endif

    // Path separator idiocy:
    // The Finder does not allow the ':' character in file names -- it beeps and changes it to '-'. So we do the same.
    // We always need to change '/' to a different character, since (as far as I know) there is no way of escaping the '/' character from NSFileManager calls. It gets changed to ":" in the Finder for all file systems, so let's just do that. (Note that the character will still display as '/'!)
    modifiedNewFileName = [modifiedNewFileName stringByReplacingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"] withString:@"-"];
    modifiedNewFileName = [modifiedNewFileName stringByReplacingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"] withString:@":"];

    newPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:modifiedNewFileName];

    fileManager = [NSFileManager defaultManager];
    
    if ([newPath isEqualToString:path])
        success = YES;
    else if ([fileManager fileExistsAtPath:newPath])
        success = NO;
    else
        success = [fileManager movePath:path toPath:newPath handler:nil];

    if (success && (shouldHideExtension || shouldShowExtension)) {
        NSDictionary *attributes;

        attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:shouldHideExtension] forKey:NSFileExtensionHidden];
        [fileManager changeFileAttributes:attributes atPath:newPath];
        // It is no big deal if this fails
    }

    if (success) {
        [self setPath:newPath];	// Update our alias to the file
        [self setNameFromFile];	// Make sure we are consistent with the Finder
    }
    
    return success;
}

- (NSArray *)messages;
{
    NSString *path;
    SSELibraryFileType fileType;
    NSArray *messages = nil;

    path = [self path];
    if (!path)
        return nil;

    fileType = [nonretainedLibrary typeOfFileAtPath:path];

    if (fileType == SSELibraryFileTypeStandardMIDI) {
        messages = [SMSystemExclusiveMessage systemExclusiveMessagesInStandardMIDIFile:path];
    } else if (fileType == SSELibraryFileTypeRaw) {
        NSData *data;

        if ((data = [NSData dataWithContentsOfFile:path]))
            messages = [SMSystemExclusiveMessage systemExclusiveMessagesInData:data];
    }

    // Always update this stuff when we read the messages
    [self updateDerivedInformationFromMessages:messages];
    
    return messages;
}

- (NSString *)manufacturer;
{
    return manufacturer;
}

- (NSNumber *)size;
{
    return sizeNumber;
}

- (NSNumber *)messageCount;
{
    return messageCountNumber;
}

- (BOOL)isFilePresent;
{
    if (!flags.hasLookedForFile)
        [self path];

    OBASSERT(flags.hasLookedForFile);
    return flags.isFilePresent;
}

- (BOOL)isFilePresentIgnoringCachedValue;
{
    flags.hasLookedForFile = NO;
    return [self isFilePresent];
}

- (BOOL)isFileInLibraryFileDirectory;
{
    if (![self isFilePresentIgnoringCachedValue])
        return NO;

    return [nonretainedLibrary isPathInFileDirectory:[self path]];
}

@end


@implementation SSELibraryEntry (Private)

+ (NSString *)manufacturerFromMessages:(NSArray *)messages;
{
    unsigned int messageIndex;
    NSString *newManufacturer = nil;

    messageIndex = [messages count];
    while (messageIndex--) {
        NSString *messageManufacturer;

        messageManufacturer = [[messages objectAtIndex:messageIndex] manufacturerName];
        if (!messageManufacturer)
            continue;

        if (!newManufacturer) {
            newManufacturer = messageManufacturer;
        } else if (![messageManufacturer isEqualToString:newManufacturer]) {
            newManufacturer = @"Various";
            break;
        }
    }

    if (!newManufacturer)
        newManufacturer = @"Unknown";	// TODO localize or get from SnoizeMIDI framework

    return newManufacturer;
}

+ (NSNumber *)sizeFromMessages:(NSArray *)messages;
{
    unsigned int messageIndex;
    unsigned int size = 0;

    messageIndex = [messages count];
    while (messageIndex--)
        size += [[messages objectAtIndex:messageIndex] fullMessageDataLength];

    return [NSNumber numberWithUnsignedInt:size];
}

+ (NSNumber *)messageCountFromMessages:(NSArray *)messages;
{
    return [NSNumber numberWithUnsignedInt:[messages count]];
}

- (void)takeValuesFromDictionary:(NSDictionary *)dict;
{
    id data, string, number;

    OBASSERT(alias == nil);
    data = [dict objectForKey:@"alias"];
    if (data && [data isKindOfClass:[NSData class]])
        alias = [[BDAlias alloc] initWithData:data];

    OBASSERT(name == nil);
    string = [dict objectForKey:@"name"];
    if (string && [string isKindOfClass:[NSString class]]) {
        name = [string retain];
    } else {
        [self setNameFromFile];
    }

    OBASSERT(manufacturer == nil);
    string = [dict objectForKey:@"manufacturerName"];
    if (string && [string isKindOfClass:[NSString class]]) {
        manufacturer = [string retain];
    }

    OBASSERT(sizeNumber == nil);
    number = [dict objectForKey:@"size"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        sizeNumber = [number retain];
    }

    OBASSERT(messageCountNumber == nil);
    number = [dict objectForKey:@"messageCount"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        messageCountNumber = [number retain];
    }
}

- (void)updateDerivedInformationFromMessages:(NSArray *)messages;
{
    [self setManufacturer:[[self class] manufacturerFromMessages:messages]];
    [self setSize:[[self class] sizeFromMessages:messages]];
    [self setMessageCount:[[self class] messageCountFromMessages:messages]];
}

- (void)setManufacturer:(NSString *)value;
{
    if (value != manufacturer && ![manufacturer isEqualToString:value]) {
        [manufacturer release];
        manufacturer = [value retain];

        [nonretainedLibrary noteEntryChanged];
    }
}

- (void)setSize:(NSNumber *)value;
{
    if (value != sizeNumber && ![sizeNumber isEqual:value]) {
        [sizeNumber release];
        sizeNumber = [value retain];
        
        [nonretainedLibrary noteEntryChanged];
    }
}

- (void)setMessageCount:(NSNumber *)value;
{
    if (value != messageCountNumber && ![messageCountNumber isEqual:value]) {
        [messageCountNumber release];
        messageCountNumber = [value retain];

        [nonretainedLibrary noteEntryChanged];
    }
}

@end
