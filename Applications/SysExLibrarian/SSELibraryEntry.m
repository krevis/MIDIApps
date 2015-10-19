/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSELibraryEntry.h"

#import <SnoizeMIDI/SnoizeMIDI.h>

#import "BDAlias.h"
#import "SSELibrary.h"


@interface SSELibraryEntry (Private)

+ (NSString *)manufacturerFromMessages:(NSArray *)messages;
+ (NSNumber *)sizeFromMessages:(NSArray *)messages;
+ (NSNumber *)messageCountFromMessages:(NSArray *)messages;

- (void)setValuesFromDictionary:(NSDictionary *)dict;

- (void)updateDerivedInformationFromMessages:(NSArray *)messages;

- (void)setManufacturer:(NSString *)value;
- (void)setSize:(NSNumber *)value;
- (void)setMessageCount:(NSNumber *)value;

@end


@implementation SSELibraryEntry

NSString *SSELibraryEntryNameDidChangeNotification = @"SSELibraryEntryNameDidChangeNotification";


- (id)initWithLibrary:(SSELibrary *)library;
{
    if (!(self = [super init]))
        return nil;

    nonretainedLibrary = library;
    flags.hasLookedForFile = NO;
    flags.isFilePresent = NO;

    return self;
}

- (id)initWithLibrary:(SSELibrary *)library dictionary:(NSDictionary *)dict;
{
    if (!(self = [self initWithLibrary:library]))
        return nil;

    [self setValuesFromDictionary:dict];
    
    return self;
}

- (id)init;
{
    SMRejectUnusedImplementation(self, _cmd);
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
	[programNumber release];
	programNumber = nil;
    
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
	if (programNumber)
        [dict setObject:programNumber forKey:@"programNumber"];

    return dict;
}

- (NSString *)path;
{
    BOOL wasFilePresent;
    NSString *path;

    wasFilePresent = flags.hasLookedForFile && flags.isFilePresent;
    
    path = [alias fullPathRelativeToPath:nil allowingUI:NO];

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
        newName = NSLocalizedStringFromTableInBundle(@"Unknown", @"SysExLibrarian", SMBundleForObject(self), "Unknown");

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
    SMAssert((shouldShowExtension && shouldHideExtension) == NO);    // We can't do both!

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
    NSMutableString* muModifiedNewFileName = [[modifiedNewFileName mutableCopy] autorelease];
    [muModifiedNewFileName replaceOccurrencesOfString:@":" withString:@"-" options:NSLiteralSearch range:NSMakeRange(0, [muModifiedNewFileName length])];
    [muModifiedNewFileName replaceOccurrencesOfString:@"/" withString:@":" options:NSLiteralSearch range:NSMakeRange(0, [muModifiedNewFileName length])];
    modifiedNewFileName = muModifiedNewFileName;

    newPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:modifiedNewFileName];

    fileManager = [NSFileManager defaultManager];
    
    if ([newPath isEqualToString:path])
        success = YES;
    else if ([fileManager fileExistsAtPath:newPath])
        success = NO;
    else
        success = [fileManager moveItemAtPath:path toPath:newPath error:NULL];

    if (success && (shouldHideExtension || shouldShowExtension)) {
        NSDictionary *attributes;

        attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:shouldHideExtension] forKey:NSFileExtensionHidden];
        [fileManager setAttributes:attributes ofItemAtPath:newPath error:NULL];
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

    SMAssert(flags.hasLookedForFile);
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

- (void)setProgramNumber:(NSNumber *)value;
{
    if (value != programNumber && ![programNumber isEqual:value]) {
        [programNumber release];
        programNumber = [value retain];
        
        [nonretainedLibrary noteEntryChanged];
    }
}
- (NSNumber *)programNumber
{
	return programNumber;
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
            newManufacturer = NSLocalizedStringFromTableInBundle(@"Various", @"SysExLibrarian", SMBundleForObject(self), "Various");
            break;
        }
    }

    if (!newManufacturer)
        newManufacturer = NSLocalizedStringFromTableInBundle(@"Unknown", @"SysExLibrarian", SMBundleForObject(self), "Unknown");

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

- (void)setValuesFromDictionary:(NSDictionary *)dict;
{
    id data, string, number;

    SMAssert(alias == nil);
    data = [dict objectForKey:@"alias"];
    if (data && [data isKindOfClass:[NSData class]])
        alias = [[BDAlias alloc] initWithData:data];

    SMAssert(name == nil);
    string = [dict objectForKey:@"name"];
    if (string && [string isKindOfClass:[NSString class]]) {
        name = [string retain];
    } else {
        [self setNameFromFile];
    }

    SMAssert(manufacturer == nil);
    string = [dict objectForKey:@"manufacturerName"];
    if (string && [string isKindOfClass:[NSString class]]) {
        manufacturer = [string retain];
    }

    number = [dict objectForKey:@"programNumber"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        programNumber = [number retain];
    }
	
    SMAssert(sizeNumber == nil);
    number = [dict objectForKey:@"size"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        sizeNumber = [number retain];
    }

    SMAssert(messageCountNumber == nil);
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
