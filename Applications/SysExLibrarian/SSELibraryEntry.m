/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if !__has_feature(objc_arc)
#error This file requires ARC.
#endif

#import "SSELibraryEntry.h"

#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSEAlias.h"
#import "SSELibrary.h"


@interface SSELibraryEntry ()

// Redeclare readwrite
@property (nonatomic, weak, readwrite) SSELibrary *library;
@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) NSString *manufacturer;
@property (nonatomic, readwrite) NSNumber *size;
@property (nonatomic, readwrite) NSNumber *messageCount;

@property (nonatomic) SSEAlias *alias;
@property (nonatomic) NSData *oldAliasRecordData;

@end


@implementation SSELibraryEntry
{
    struct {
        unsigned int isFilePresent:1;
        unsigned int hasLookedForFile:1;
    } _flags;
}

NSString *SSELibraryEntryNameDidChangeNotification = @"SSELibraryEntryNameDidChangeNotification";


- (id)initWithLibrary:(SSELibrary *)library
{
    if ((self = [super init])) {
        _library = library;
        _flags.hasLookedForFile = NO;
        _flags.isFilePresent = NO;
    }

    return self;
}

- (id)initWithLibrary:(SSELibrary *)library dictionary:(NSDictionary *)dict
{
    if ((self = [self initWithLibrary:library])) {
        [self setValuesFromDictionary:dict];
    }
    
    return self;
}

- (id)init
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (NSDictionary *)dictionaryValues
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (_alias.data) {
        [dict setObject:_alias.data forKey:@"bookmark"];
    }
    if (_oldAliasRecordData) {
        [dict setObject:_oldAliasRecordData forKey:@"alias"];
    }
    if (_name) {
        [dict setObject:_name forKey:@"name"];
    }

    if (_manufacturer) {
        [dict setObject:_manufacturer forKey:@"manufacturerName"];
    }
    if (_size) {
        [dict setObject:_size forKey:@"size"];
    }
    if (_messageCount) {
        [dict setObject:_messageCount forKey:@"messageCount"];
    }
    if (_programNumber) {
        [dict setObject:_programNumber forKey:@"programNumber"];
    }

    return dict;
}

- (NSString *)path
{
    BOOL wasFilePresent = _flags.hasLookedForFile && _flags.isFilePresent;
    
    NSString *path = [_alias pathAllowingUI:NO];

    _flags.hasLookedForFile = YES;
    _flags.isFilePresent = (path && [[NSFileManager defaultManager] fileExistsAtPath:path]);

    if (_flags.isFilePresent != wasFilePresent) {
        [self.library noteEntryChanged];
    }

    if (_flags.isFilePresent) {
        [self setName:[[NSFileManager defaultManager] displayNameAtPath:path]];
    }

    return path;
}

- (void)setPath:(NSString *)value
{
    _alias = [[SSEAlias alloc] initWithPath:value];
    _oldAliasRecordData = nil;

    [self.library noteEntryChanged];
}

- (void)setName:(NSString *)value
{
    if (_name != value && ![_name isEqualToString:value]) {
        _name = value;

        [[NSNotificationCenter defaultCenter] postNotificationName:SSELibraryEntryNameDidChangeNotification object:self];
        [self.library noteEntryChanged];
    }
}

- (void)setNameFromFile
{
    NSString *newName = nil;

    NSString *path = [self path];
    if (path) {
        newName = [[NSFileManager defaultManager] displayNameAtPath:path];
    }

    if (!newName) {
        newName = NSLocalizedStringFromTableInBundle(@"Unknown", @"SysExLibrarian", SMBundleForObject(self), "Unknown");
    }

    [self setName:newName];
}

- (BOOL)renameFileTo:(NSString *)newFileName
{
    NSString *path = [self path];
    if (!path) {
        return NO;
    }

    NSString *fileName = [path lastPathComponent];
    NSString *extension = [fileName pathExtension];

    // Calculate the new file name, keeping the same extension as before.
    // TODO Is that really exactly what we want?
    NSString *modifiedNewFileName;
    BOOL shouldHideExtension = NO;
    BOOL shouldShowExtension = NO;
    if (extension && [extension length] > 0) {
        // The old file name had an extension. We need to make sure the new name has the same extension.
        NSString *newExtension = [newFileName pathExtension];
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
    NSMutableString* muModifiedNewFileName = [modifiedNewFileName mutableCopy];
    [muModifiedNewFileName replaceOccurrencesOfString:@":" withString:@"-" options:NSLiteralSearch range:NSMakeRange(0, [muModifiedNewFileName length])];
    [muModifiedNewFileName replaceOccurrencesOfString:@"/" withString:@":" options:NSLiteralSearch range:NSMakeRange(0, [muModifiedNewFileName length])];
    modifiedNewFileName = muModifiedNewFileName;

    NSString *newPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:modifiedNewFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL success = NO;

    if ([newPath isEqualToString:path]) {
        success = YES;
    }
    else if ([fileManager fileExistsAtPath:newPath]) {
        success = NO;
    }
    else {
        success = [fileManager moveItemAtPath:path toPath:newPath error:NULL];
    }

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

- (NSArray *)messages
{
    NSArray *messages = nil;

    NSString *path = [self path];
    if (path) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            SSELibraryFileType fileType = [self.library typeOfFileAtPath:path];

            if (fileType == SSELibraryFileTypeStandardMIDI) {
                messages = [SMSystemExclusiveMessage messagesFromStandardMIDIFileData:data];
            }
            else if (fileType == SSELibraryFileTypeRaw) {
                messages = [SMSystemExclusiveMessage messagesFromData:data];
            }
        }
    }

    // Always update this stuff when we read the messages
    // TODO But perhaps not, if there was an error reading the file
    [self updateDerivedInformationFromMessages:messages];
    
    return messages;
}

- (BOOL)isFilePresent
{
    if (!_flags.hasLookedForFile) {
        [self path];
    }

    SMAssert(_flags.hasLookedForFile);
    return _flags.isFilePresent;
}

- (BOOL)isFilePresentIgnoringCachedValue
{
    _flags.hasLookedForFile = NO;
    return [self isFilePresent];
}

- (BOOL)isFileInLibraryFileDirectory
{
    if (![self isFilePresentIgnoringCachedValue]) {
        return NO;
    }

    return [self.library isPathInFileDirectory:[self path]];
}

- (void)setProgramNumber:(NSNumber *)value
{
    if (value != _programNumber && ![_programNumber isEqual:value]) {
        _programNumber = value;
        
        [self.library noteEntryChanged];
    }
}	

#pragma mark Private

+ (NSString *)manufacturerFromMessages:(NSArray *)messages
{
    NSString *newManufacturer = nil;

    for (SMSystemExclusiveMessage *message in messages) {
        NSString *messageManufacturer = [message manufacturerName];
        if (!messageManufacturer) {
            continue;
        }

        if (!newManufacturer) {
            newManufacturer = messageManufacturer;
        } else if (![messageManufacturer isEqualToString:newManufacturer]) {
            newManufacturer = NSLocalizedStringFromTableInBundle(@"Various", @"SysExLibrarian", SMBundleForObject(self), "Various");
            break;
        }
    }

    if (!newManufacturer) {
        newManufacturer = NSLocalizedStringFromTableInBundle(@"Unknown", @"SysExLibrarian", SMBundleForObject(self), "Unknown");
    }

    return newManufacturer;
}

+ (NSNumber *)sizeFromMessages:(NSArray *)messages
{
    NSUInteger size = 0;
    for (SMSystemExclusiveMessage *message in messages) {
        size += [message fullMessageDataLength];
    }

    return [NSNumber numberWithUnsignedInteger:size];
}

+ (NSNumber *)messageCountFromMessages:(NSArray *)messages
{
    return [NSNumber numberWithUnsignedInteger:[messages count]];
}

- (void)setValuesFromDictionary:(NSDictionary *)dict
{
    id data, string, number;

    SMAssert(_alias == nil);
    data = [dict objectForKey:@"bookmark"];
    if (data && [data isKindOfClass:[NSData class]]) {
        _alias = [[SSEAlias alloc] initWithData:data];
    }

    // backwards compatibility
    data = [dict objectForKey:@"alias"];
    if (data && [data isKindOfClass:[NSData class]]) {
        // Use this to create an alias if we didn't already
        if (!_alias) {
            _alias = [[SSEAlias alloc] initWithAliasRecordData:data];
        }
        // Save this data to write out for old clients
        _oldAliasRecordData = data;
    }

    SMAssert(_name == nil);
    string = [dict objectForKey:@"name"];
    if (string && [string isKindOfClass:[NSString class]]) {
        _name = string;
    } else {
        [self setNameFromFile];
    }

    SMAssert(_manufacturer == nil);
    string = [dict objectForKey:@"manufacturerName"];
    if (string && [string isKindOfClass:[NSString class]]) {
        _manufacturer = string;
    }

    number = [dict objectForKey:@"programNumber"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        _programNumber = number;
    }
	
    SMAssert(_size == nil);
    number = [dict objectForKey:@"size"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        _size = number;
    }

    SMAssert(_messageCount == nil);
    number = [dict objectForKey:@"messageCount"];
    if (number && [number isKindOfClass:[NSNumber class]]) {
        _messageCount = number;
    }
}

- (void)updateDerivedInformationFromMessages:(NSArray *)messages
{
    [self setManufacturer:[[self class] manufacturerFromMessages:messages]];
    [self setSize:[[self class] sizeFromMessages:messages]];
    [self setMessageCount:[[self class] messageCountFromMessages:messages]];
}

- (void)setManufacturer:(NSString *)value
{
    if (value != _manufacturer && ![_manufacturer isEqualToString:value]) {
        _manufacturer = value;

        [self.library noteEntryChanged];
    }
}

- (void)setSize:(NSNumber *)value
{
    if (value != _size && ![_size isEqual:value]) {
        _size = value;
        
        [self.library noteEntryChanged];
    }
}

- (void)setMessageCount:(NSNumber *)value
{
    if (value != _messageCount && ![_messageCount isEqual:value]) {
        _messageCount = value;

        [self.library noteEntryChanged];
    }
}

@end
