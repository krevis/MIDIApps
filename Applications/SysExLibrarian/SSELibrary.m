/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSELibrary.h"

@import SnoizeMIDI;

#import "SSELibraryEntry.h"
#import "NSString+SymlinksAndAliases.h"
#import "SysEx_Librarian-Swift.h"


@implementation SSELibrary
{
    NSMutableArray<SSELibraryEntry *> *entries;
    struct {
        unsigned int isDirty:1;
        unsigned int willPostLibraryDidChangeNotification:1;
    } flags;

    NSArray<NSString *> *rawSysExFileTypes;
    NSArray<NSString *> *standardMIDIFileTypes;
    NSArray<NSString *> *allowedFileTypes;
}

NSNotificationName const SSELibraryDidChangeNotification = @"SSELibraryDidChangeNotification";
NSNotificationName const SSELibraryEntryWillBeRemovedNotification = @"SSELibraryEntryWillBeRemovedNotification";

NSString * const SSELibraryFileDirectoryBookmarkPreferenceKey = @"SSELibraryFileDirectoryBookmark";
NSString * const SSELibraryFileDirectoryAliasPreferenceKey = @"SSELibraryFileDirectoryAlias";
NSString * const SSELibraryFileDirectoryPathPreferenceKey = @"SSELibraryFileDirectoryPath";

const FourCharCode SSEApplicationCreatorCode = 'SnSX';
const FourCharCode SSELibraryFileTypeCode = 'sXLb';
const FourCharCode SSESysExFileTypeCode = 'sysX';
NSString * const SSESysExFileExtension = @"syx";

+ (SSELibrary *)sharedLibrary
{
    static SSELibrary *sSharedLibrary = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSharedLibrary = [[self alloc] init];
    });

    return sSharedLibrary;
}

- (id)init
{
    if (!(self = [super init])) {
        return nil;
    }

    NSArray *documentTypes = [[SMBundleForObject(self) infoDictionary] objectForKey:@"CFBundleDocumentTypes"];
    if ([documentTypes count] > 0) {
        NSDictionary *documentTypeDict = [documentTypes objectAtIndex:0];
        rawSysExFileTypes = [[self fileTypesFromDocumentTypeDictionary:documentTypeDict] retain];

        if ([documentTypes count] > 1) {
            documentTypeDict = [documentTypes objectAtIndex:1];
            standardMIDIFileTypes = [[self fileTypesFromDocumentTypeDictionary:documentTypeDict] retain];
        }
    }
    allowedFileTypes = [[rawSysExFileTypes arrayByAddingObjectsFromArray:standardMIDIFileTypes] retain];

    entries = [[NSMutableArray alloc] init];
    flags.isDirty = NO;

    return self;
}

- (void)dealloc
{
    [entries release];
    entries = nil;
    [rawSysExFileTypes release];
    rawSysExFileTypes = nil;
    [standardMIDIFileTypes release];
    standardMIDIFileTypes = nil;
    [allowedFileTypes release];
    allowedFileTypes = nil;

    [super dealloc];
}

- (NSString *)libraryFilePath
{
    static NSString *libraryFilePath = nil;

    if (!libraryFilePath) {
        NSURL *homeLibraryURL = [[NSFileManager defaultManager] URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
        if (homeLibraryURL) {
            NSString *homeLibraryPath = [homeLibraryURL path];
            NSString *preferencesFolderPath = [homeLibraryPath stringByAppendingPathComponent:@"Preferences"];
            // This path should exist as-is; don't bother trying to resolve symlinks or aliases.

            libraryFilePath = [preferencesFolderPath stringByAppendingPathComponent:@"SysEx Librarian Library.sXLb"];
            [libraryFilePath retain];
        }
    }

    return libraryFilePath;
}

- (NSString *)rememberedFileDirectoryPath
{
    NSString *path = nil;

    NSData *bookmarkData = [[NSUserDefaults standardUserDefaults] dataForKey:SSELibraryFileDirectoryBookmarkPreferenceKey];
    if (bookmarkData) {
        path = [[[[Alias alloc] initWithData:bookmarkData] autorelease] path];
    }
    else {
        NSData *aliasData = [[NSUserDefaults standardUserDefaults] dataForKey:SSELibraryFileDirectoryAliasPreferenceKey];
        if (aliasData) {
            path = [[[[Alias alloc] initWithAliasRecordData:aliasData] autorelease] path];
        }
        else {
            path = [[NSUserDefaults standardUserDefaults] stringForKey:SSELibraryFileDirectoryPathPreferenceKey];
        }
    }

    return path;
}

- (void)clearRememberedFileDirectoryPath
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:SSELibraryFileDirectoryBookmarkPreferenceKey];
    [defaults removeObjectForKey:SSELibraryFileDirectoryAliasPreferenceKey];
    [defaults removeObjectForKey:SSELibraryFileDirectoryPathPreferenceKey];
}

- (NSString *)fileDirectoryPath
{
    return [self rememberedFileDirectoryPath] ?: [self defaultFileDirectoryPath];
}

- (void)setFileDirectoryPath:(NSString *)newPath
{
    Alias *alias = [[Alias alloc] initWithPath:newPath];
    SMAssert([alias path] != nil);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[alias data] forKey:SSELibraryFileDirectoryBookmarkPreferenceKey];
    // Clear anything that might have been in old SSELibraryFileDirectoryAliasPreferenceKey. if someone runs an old version of the app, let it fall back via the path.
    [defaults setObject:nil forKey:SSELibraryFileDirectoryAliasPreferenceKey];
    [defaults setObject:newPath forKey:SSELibraryFileDirectoryPathPreferenceKey];

    [alias release];
}

- (BOOL)isPathInFileDirectory:(NSString *)path
{
    return [path hasPrefix:[[self fileDirectoryPath] stringByAppendingString:@"/"]];
}

- (NSString *)preflightAndLoadEntries
{
    NSString *errorMessage = [self preflightLibrary];
    if (errorMessage) {
        // Currently, the only reason this can fail is in the unlikely event that we can't get a URL to ~/Library/
        NSString *format = NSLocalizedStringFromTableInBundle(@"There is a problem accessing the SysEx Librarian preferences.\n%@", @"SysExLibrarian", SMBundleForObject(self), "error message on preflight library");
        return [NSString stringWithFormat:format, errorMessage];
    }

    [self preflightFileDirectory];  // can't produce any fatal errors for launch

    [self loadEntries];
    return nil;
}

- (NSArray<SSELibraryEntry *> *)entries
{
    return entries;
}

- (SSELibraryEntry *)addEntryForFile:(NSString *)filePath
{
    // Setting the entry path and name will cause us to be notified of a change, and we'll autosave.
    // However, the add might not succeed--if it doesn't, make sure our dirty flag isn't set if it shouldn't be.

    BOOL wasDirty = flags.isDirty;

    SSELibraryEntry *entry = [[SSELibraryEntry alloc] initWithLibrary:self];
    [entry setPath:filePath];

    if ([[entry messages] count] > 0) {
        [entry setNameFromFile];
        [entries addObject:entry];
        [entry release];
    } else {
        [entry release];
        entry = nil;
        if (!wasDirty) {
            flags.isDirty = NO;
        }
    }
    
    return entry;
}

- (SSELibraryEntry *)addNewEntryWithData:(NSData *)sysexData error:(NSError **)outErrorPtr
{
    SSELibraryEntry *entry = nil;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fileDirectoryPath = [self fileDirectoryPath];

    // ensure the file directory exists; if not we can't write there
    NSDictionary<NSFileAttributeKey, id> *attributes = @{NSFilePosixPermissions : @0755};
    NSError *error = nil;
    BOOL createdOrExists = [fileManager createDirectoryAtPath:fileDirectoryPath withIntermediateDirectories:YES attributes:attributes error:&error];
    if (createdOrExists) {
        NSString *newFileName = NSLocalizedStringFromTableInBundle(@"Untitled", @"SysExLibrarian", SMBundleForObject(self), "name of new sysex file");
        NSString *newFilePath = [[fileDirectoryPath stringByAppendingPathComponent:newFileName] stringByAppendingPathExtension:SSESysExFileExtension];
        newFilePath = [fileManager uniqueFilenameFrom:newFilePath];

        BOOL wrote = [sysexData writeToFile:newFilePath options:NSDataWritingAtomic error:&error];
        if (wrote) {
            NSDictionary *fileAttributes = @{ NSFileHFSTypeCode: [NSNumber numberWithUnsignedLong:SSESysExFileTypeCode],
                                              NSFileHFSCreatorCode: [NSNumber numberWithUnsignedLong:SSEApplicationCreatorCode],
                                              NSFileExtensionHidden: @(YES),
                                              };
            [[NSFileManager defaultManager] setAttributes:fileAttributes ofItemAtPath:newFilePath error:NULL];
            // If we fail to set attributes, it doesn't really matter

            entry = [self addEntryForFile:newFilePath];
            // TODO We will write out the file and then soon afterwards read it in again to get the messages. Pretty inefficient.
        }
    }

    if (error && outErrorPtr) {
        *outErrorPtr = error;
    }

    return entry;
}

- (void)removeEntry:(SSELibraryEntry *)entry
{
    NSUInteger entryIndex = [entries indexOfObjectIdenticalTo:entry];
    if (entryIndex != NSNotFound) {
        [self postEntryWillBeRemovedNotificationForEntry:[entries objectAtIndex:entryIndex]];
        [entries removeObjectAtIndex:entryIndex];

        [self noteEntryChanged];
    }
}

- (void)removeEntries:(NSArray<SSELibraryEntry *> *)entriesToRemove
{
    for (SSELibraryEntry *entry in entriesToRemove) {
        [self postEntryWillBeRemovedNotificationForEntry:entry];
    }

    [entries SnoizeMIDI_removeObjectsIdenticalToObjectsInArray:entriesToRemove];

    [self noteEntryChanged];
}

- (void)noteEntryChanged
{
    flags.isDirty = YES;
    [self autosave];

    if (!flags.willPostLibraryDidChangeNotification) {
        flags.willPostLibraryDidChangeNotification = YES;
        [self retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            flags.willPostLibraryDidChangeNotification = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:SSELibraryDidChangeNotification object:self];
            [self autorelease];
        });
    }
}

- (void)autosave
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    [self performSelector:@selector(save) withObject:nil afterDelay:0.0];
}

- (void)save
{
    if (!flags.isDirty) {
        return;
    }
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSMutableArray *entryDicts = [NSMutableArray array];

    for (SSELibraryEntry *entry in entries) {
        NSDictionary *entryDict = [entry dictionaryValues];
        if (entryDict) {
            [entryDicts addObject:entryDict];
        }
    }

    [dictionary setObject:entryDicts forKey:@"Entries"];

    NSString *libraryFilePath = [self libraryFilePath];

    NSError *error = nil;
    NSData* fileData = [NSPropertyListSerialization dataWithPropertyList:dictionary format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (fileData) {
        BOOL wrote = [fileData writeToFile:libraryFilePath options:NSDataWritingAtomic error:&error];
        if (wrote) {
            NSDictionary *fileAttributes = @{ NSFileHFSTypeCode: [NSNumber numberWithUnsignedLong:SSELibraryFileTypeCode],
                                              NSFileHFSCreatorCode: [NSNumber numberWithUnsignedLong:SSEApplicationCreatorCode],
                                              NSFileExtensionHidden: @(YES),
                                              };
            [[NSFileManager defaultManager] setAttributes:fileAttributes ofItemAtPath:libraryFilePath error:NULL];
            // If we fail to set attributes, it doesn't really matter
        }
    }

    if (error) {
        // Present the error, Can't continue saving, but can continue with the app.
        // This is not fantastic UI, but it works.  This should not happen unless the user is trying to provoke us, anyway.
        NSString *title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
        NSString *messageFormat = NSLocalizedStringFromTableInBundle(@"The library \"%@\" could not be saved.\n%@", @"SysExLibrarian", SMBundleForObject(self), "format of error message if the library file can't be saved");
        NSRunCriticalAlertPanel(title, messageFormat, nil, nil, nil, libraryFilePath, error.localizedDescription);
    }
    else {
        flags.isDirty = NO;
    }
}

- (NSArray<NSString *> *)allowedFileTypes
{
    return allowedFileTypes;
}

- (SSELibraryFileType)typeOfFileAtPath:(NSString *)filePath
{
    if (!filePath || [filePath length] == 0) {
        return SSELibraryFileTypeUnknown;
    }
    
    NSString *fileType = [filePath pathExtension];
    if (!fileType || [fileType length] == 0) {
        fileType = NSHFSTypeOfFile(filePath);
    }

    if ([rawSysExFileTypes indexOfObject:fileType] != NSNotFound) {
        return SSELibraryFileTypeRaw;
    } else if ([standardMIDIFileTypes indexOfObject:fileType] != NSNotFound) {
        return SSELibraryFileTypeStandardMIDI;
    } else {
        return SSELibraryFileTypeUnknown;
    }
}

- (NSArray *)findEntriesForFiles:(NSArray *)filePaths returningNonMatchingFiles:(NSArray **)nonMatchingFilePathsPtr
{
    NSMutableDictionary<NSString *, SSELibraryEntry *> *entriesByFilePath = [NSMutableDictionary dictionaryWithCapacity:entries.count];
    for (SSELibraryEntry *entry in entries) {
        NSString *filePath = [entry path];
        if (filePath) {
            SMAssert([entriesByFilePath objectForKey:filePath] == nil);
            [entriesByFilePath setObject:entry forKey:filePath];
        }
    }

    NSMutableArray<NSString *> *nonMatchingFilePaths = [NSMutableArray arrayWithCapacity:filePaths.count];
    NSMutableArray<SSELibraryEntry *> *matchingEntries = [NSMutableArray arrayWithCapacity:filePaths.count];

    for (NSString *filePath in filePaths) {
        SSELibraryEntry *entry = [entriesByFilePath objectForKey:filePath];
        if (entry) {
            [matchingEntries addObject:entry];
        } else {
            [nonMatchingFilePaths addObject:filePath];
        }
    }
        
    if (nonMatchingFilePathsPtr) {
        *nonMatchingFilePathsPtr = nonMatchingFilePaths;
    }

    return matchingEntries;
}

- (void)moveFilesInLibraryDirectoryToTrashForEntries:(NSArray<SSELibraryEntry *> *)entriesToTrash
{
    NSMutableArray<NSString *> *filesToTrash = [NSMutableArray arrayWithCapacity:entriesToTrash.count];
    for (SSELibraryEntry *entry in entriesToTrash) {
        if ([entry isFileInLibraryFileDirectory]) {
            [filesToTrash addObject:[entry path]];
        }
    }

    if ([filesToTrash count] > 0) {
        NSMutableArray<NSURL *> *urls = [NSMutableArray array];
        for (NSString *filePath in filesToTrash) {
            NSURL *url = [NSURL fileURLWithPath:filePath];
            if (url) {
                [urls addObject:url];
            }
        }
        [[NSWorkspace sharedWorkspace] recycleURLs:urls completionHandler:nil];
    }
}


#pragma mark Private

- (NSString *)defaultFileDirectoryPath
{
    // Ideally put it in ~/Documents
    NSURL *homeDocumentsURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    NSString *parentPath = homeDocumentsURL.path ?: [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    return [parentPath stringByAppendingPathComponent:@"SysEx Librarian"];
}

- (NSString *)preflightLibrary
{
    // This used to do more, but now we only check for absolutely fatal errors.

    NSError *error;
    NSURL *homeLibraryURL = [[NSFileManager defaultManager] URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    if (!homeLibraryURL) {
        // This is really unlikely, but we really can't do much if this fails. Fatal error.
        return [error localizedDescription];
    }

    return nil;
}

- (void)preflightFileDirectory
{
    // Note: the fileDirectory only really affects the location of newly added files,
    // and whether we show alerts when removing files. Its value isn't critical, as long
    // as we can find somewhere we can write to.

    NSFileManager *fileManager = [NSFileManager defaultManager];

    // If we have a remembered file directory (either via a bookmark, alias, or path),
    // check whether it still exists. If not, then clear it and go back to the default.
    // (If it doesn't exist, it could be for some user name that doesn't exist, or could be wrong
    //  for some reason that's hard to recover from. Better to just ignore it.)
    NSString *rememberedFileDirectoryPath = [self rememberedFileDirectoryPath];
    if (rememberedFileDirectoryPath) {
        BOOL isDirectory;
        BOOL exists = [fileManager fileExistsAtPath:rememberedFileDirectoryPath isDirectory:&isDirectory];
        if (!(exists && isDirectory)) {
            [self clearRememberedFileDirectoryPath];
            rememberedFileDirectoryPath = nil;
        }
    }

    // There is no need to do anything else with fileDirectoryPath. When we use it when recording a new sysex file,
    // we will ensure it (and its intermediate directories) exists, and present an error if there are any problems.
}

- (void)loadEntries
{
    // We should only be called once at startup
    SMAssert([entries count] == 0);

    NSString *libraryFilePath = [self libraryFilePath];
    // Handle the case when someone has replaced our file with a symlink, an alias, or a symlink to an alias.
    // (If you have more symlinks or aliases chained together, well, sorry.)
    // Note that this only affects the data that we read. When we write we will replace the symlink or alias with a plain file.
    NSString *resolvedLibraryFilePath = [[libraryFilePath SSE_stringByResolvingSymlink] SSE_stringByResolvingAlias];

    NSError *error = nil;
    NSData* data = [NSData dataWithContentsOfFile:resolvedLibraryFilePath options:0 error:&error];
    if (data) {
        id propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:&error];
        if (propertyList && [propertyList isKindOfClass:[NSDictionary class]]) {
            NSDictionary *libraryDictionary = (NSDictionary *)propertyList;
            NSArray *entryDicts = [libraryDictionary objectForKey:@"Entries"];
            for (NSDictionary *entryDict in entryDicts) {
                SSELibraryEntry *entry = [[SSELibraryEntry alloc] initWithLibrary:self dictionary:entryDict];
                if (entry) {
                    [entries addObject:entry];
                }
                [entry release];
            }
        }
    }
    else /* data == nil */ {
        // Ignore file not found errors. That just means there isn't a file to read from.
        if (error && error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError) {
            error = nil;
        }
        else {
            NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
            if (underlyingError && underlyingError.domain == NSPOSIXErrorDomain && underlyingError.code == ENOENT) {
                error = nil;
            }
        }
    }

    if (error) {
        // Report on error, then continue with an empty library.
        NSString *title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
        NSString *messageFormat = NSLocalizedStringFromTableInBundle(@"The library \"%@\" could not be read.\n%@", @"SysExLibrarian", SMBundleForObject(self), "format of error message if the library file can't be read");
        NSRunCriticalAlertPanel(title, messageFormat, nil, nil, nil, libraryFilePath, error.localizedDescription);
    }

    // Ignore any changes that came from reading entries
    flags.isDirty = NO;
}

- (NSArray *)fileTypesFromDocumentTypeDictionary:(NSDictionary *)documentTypeDict
{
    NSMutableArray *fileTypes = [NSMutableArray array];

    NSArray *extensions = [documentTypeDict objectForKey:@"CFBundleTypeExtensions"];
    if (extensions && [extensions isKindOfClass:[NSArray class]]) {
        [fileTypes addObjectsFromArray:extensions];
    }

    NSArray *osTypes = [documentTypeDict objectForKey:@"CFBundleTypeOSTypes"];
    if (osTypes && [osTypes isKindOfClass:[NSArray class]]) {
        NSUInteger osTypeIndex, osTypeCount;

        osTypeCount = [osTypes count];
        for (osTypeIndex = 0; osTypeIndex < osTypeCount; osTypeIndex++) {
            [fileTypes addObject:[NSString stringWithFormat:@"'%@'", [osTypes objectAtIndex:osTypeIndex]]];
        }
    }

    return fileTypes;
}

- (void)postEntryWillBeRemovedNotificationForEntry:(SSELibraryEntry *)entry
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSELibraryEntryWillBeRemovedNotification object:entry];
}

@end
