/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSELibrary.h"

#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSEAlias.h"
#import "SSELibraryEntry.h"
#import "NSString+SymlinksAndAliases.h"
#import "NSFileManager-Extensions.h"


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
        NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *homeLibraryPath = [paths firstObject] ?: [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
        NSString *preferencesFolderPath = [homeLibraryPath stringByAppendingPathComponent:@"Preferences"];
        // This path should exist as-is; don't bother trying to resolve symlinks or aliases.

        libraryFilePath = [preferencesFolderPath stringByAppendingPathComponent:@"SysEx Librarian Library.sXLb"];

        [libraryFilePath retain];
    }

    return libraryFilePath;
}

- (NSString *)fileDirectoryPath
{
    NSString *path = nil;

    NSData *bookmarkData = [[NSUserDefaults standardUserDefaults] dataForKey:SSELibraryFileDirectoryBookmarkPreferenceKey];
    if (bookmarkData) {
        path = [[SSEAlias aliasWithData:bookmarkData] path];
    }
    else {
        NSData *aliasData = [[NSUserDefaults standardUserDefaults] dataForKey:SSELibraryFileDirectoryAliasPreferenceKey];
        if (aliasData) {
            path = [[SSEAlias aliasWithAliasRecordData:aliasData] path];
        }
    }

    if (path) {
        // Make sure the saved path is in sync with what the alias resolved
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:SSELibraryFileDirectoryPathPreferenceKey];
    } else {
        // Couldn't resolve the alias, so fall back to the path (which may not exist yet)
        path = [[NSUserDefaults standardUserDefaults] stringForKey:SSELibraryFileDirectoryPathPreferenceKey];
    }

    if (!path) {
        path = [self defaultFileDirectoryPath];
    }

    path = [path SSE_stringByResolvingSymlinksAndAliases];

    return path;
}

- (void)setFileDirectoryPath:(NSString *)newPath
{
    if (!newPath) {
        newPath = [[self defaultFileDirectoryPath] SSE_stringByResolvingSymlinksAndAliases];
    }
    
    SSEAlias *alias = [SSEAlias aliasWithPath:newPath];
    SMAssert([alias path] != nil);

    [[NSUserDefaults standardUserDefaults] setObject:[alias data] forKey:SSELibraryFileDirectoryBookmarkPreferenceKey];
    // TODO back-compat save data for SSELibraryFileDirectoryAliasPreferenceKey ? or clear it?
    [[NSUserDefaults standardUserDefaults] setObject:newPath forKey:SSELibraryFileDirectoryPathPreferenceKey];
}

- (BOOL)isPathInFileDirectory:(NSString *)path
{
    return [path hasPrefix:[[self fileDirectoryPath] stringByAppendingString:@"/"]];
}

- (NSString *)preflightAndLoadEntries
{
    NSString *errorMessage;

    if ((errorMessage = [self preflightLibrary])) {
        NSString *format = NSLocalizedStringFromTableInBundle(@"There is a problem accessing the library \"%@\".\n%@", @"SysExLibrarian", SMBundleForObject(self), "error message if library file can't be read (preflight)");
        // TODO perhaps resolve the path here. only the last component should be problematic
        NSString *path = [[self libraryFilePath] stringByDeletingPathExtension];
        return [NSString stringWithFormat:format, path, errorMessage];
    }

    if ((errorMessage = [self preflightFileDirectory])) {
        NSString *format = NSLocalizedStringFromTableInBundle(@"There is a problem accessing the SysEx files folder \"%@\".\n%@", @"SysExLibrarian", SMBundleForObject(self), "error message if SysEx files folder can't be accessed (preflight)");
        NSString *path = [self fileDirectoryPath];
        return [NSString stringWithFormat:format, path, errorMessage];
    }

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

- (SSELibraryEntry *)addNewEntryWithData:(NSData *)sysexData
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *newFileName = NSLocalizedStringFromTableInBundle(@"Untitled", @"SysExLibrarian", SMBundleForObject(self), "name of new sysex file");
    NSString *newFilePath = [[[self fileDirectoryPath] stringByAppendingPathComponent:newFileName] stringByAppendingPathExtension:SSESysExFileExtension];
    newFilePath = [fileManager SSE_uniqueFilenameFromName:newFilePath];

    [fileManager SSE_createPathToFile:newFilePath attributes:nil];
    // NOTE This will raise an NSGenericException if it fails

    NSDictionary *newFileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedLong:SSESysExFileTypeCode], NSFileHFSTypeCode,
        [NSNumber numberWithUnsignedLong:SSEApplicationCreatorCode], NSFileHFSCreatorCode,
        [NSNumber numberWithBool:YES], NSFileExtensionHidden, nil];

    SSELibraryEntry *entry = nil;
    if ([fileManager createFileAtPath:newFilePath contents:sysexData attributes:newFileAttributes]) {
        entry = [self addEntryForFile:newFilePath];
        // TODO We will write out the file and then soon afterwards read it in again to get the messages. Pretty inefficient.
    } else {
        NSString *format;

        format = NSLocalizedStringFromTableInBundle(@"Couldn't create the file %@", @"SysExLibrarian", SMBundleForObject(self), "format of exception if can't create new sysex file");
        [NSException raise:NSGenericException format:format, newFilePath];
    }

    SMAssert(entry != nil);

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
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *libraryFilePath = [self libraryFilePath];
    // TODO resolve symlinks / aliases in libraryFilePath in save
    NSString *errorMessage = nil;

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSMutableArray *entryDicts = [NSMutableArray array];

    for (SSELibraryEntry *entry in entries) {
        NSDictionary *entryDict = [entry dictionaryValues];
        if (entryDict) {
            [entryDicts addObject:entryDict];
        }
    }

    [dictionary setObject:entryDicts forKey:@"Entries"];

    NSData *fileData = [NSPropertyListSerialization dataFromPropertyList:dictionary format:NSPropertyListXMLFormat_v1_0 errorDescription:&errorMessage];
    if (errorMessage) {
        [errorMessage autorelease]; // docs say we're supposed to release this string, oddly enough
    } else {    
        // TODO SSE_createPathToFile should basically not be necessary while we are using Preferences
        @try {
            [fileManager SSE_createPathToFile:libraryFilePath attributes:nil];
        }
        @catch (NSException *localException) {
            errorMessage = [[[localException reason] retain] autorelease];
        }
    }

    if (!errorMessage) {
        NSDictionary *fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedLong:SSELibraryFileTypeCode], NSFileHFSTypeCode,
            [NSNumber numberWithUnsignedLong:SSEApplicationCreatorCode], NSFileHFSCreatorCode,
            [NSNumber numberWithBool:YES], NSFileExtensionHidden, nil];

        // TODO use a method that returns an NSError, perhaps (on NSData, but then how to set attributes?)
        if (![fileManager createFileAtPath:libraryFilePath contents:fileData attributes:fileAttributes]) {
            errorMessage = NSLocalizedStringFromTableInBundle(@"The file could not be written.", @"SysExLibrarian", SMBundleForObject(self), "error message if sysex file can't be written");
        }
    }

    if (errorMessage) {
        // TODO this should use NSError

        NSString *title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
        NSString *messageFormat = NSLocalizedStringFromTableInBundle(@"The library \"%@\" could not be saved.\n%@", @"SysExLibrarian", SMBundleForObject(self), "format of error message if the library file can't be saved");
        
        NSRunCriticalAlertPanel(title, messageFormat, nil, nil, nil, libraryFilePath, errorMessage);
        // NOTE This is not fantastic UI, but it basically works.  This should not happen unless the user is trying to provoke us, anyway.
    } else {
        flags.isDirty = NO;
    }
}

- (NSArray *)allowedFileTypes
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
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsFolderPath = [paths firstObject] ?: [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    documentsFolderPath = [documentsFolderPath stringByAppendingPathComponent:@"SysEx Librarian"];

    return documentsFolderPath;
}

- (NSString *)preflightLibrary
{
    // Check that the library file can be read and written.

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *libraryFilePath = [self libraryFilePath];
    if (!libraryFilePath) {
        // TODO preflight library, no libraryFilePath, something very wrong
    }

    NSString *libraryFileParentPath = [libraryFilePath stringByDeletingLastPathComponent];
    if (!libraryFileParentPath) {
        // TODO preflight library, no libraryFileParentPath, something very wrong
    }

    NSString *resolvedLibraryFileParentPath = [libraryFileParentPath SSE_stringByResolvingSymlinksAndAliases];
    if (!resolvedLibraryFileParentPath) {
        // TODO preflight library, can't resolve libraryFileParentPath, something very wrong -or- a component hasn't been created yet...
    }

    // Try creating the path to the file, first.
    // TODO This should basically not be necessary while we are using Preferences
    @try {
        [fileManager SSE_createPathToFile:libraryFilePath attributes:nil];
    }
    @catch (NSException *exception) {
        return [exception reason];
    }

    // Then check that the file's parent directory is readable, writable, and searchable.
    NSString *parentDirectoryPath = [libraryFilePath stringByDeletingLastPathComponent];
    NSString *errorFormat = nil;
    if (![fileManager isReadableFileAtPath:parentDirectoryPath]) {
        errorFormat = NSLocalizedStringFromTableInBundle(@"The privileges of the folder \"%@\" do not allow reading.", @"SysExLibrarian", SMBundleForObject(self), "format of error message if library file's folder can't be read");
    } else if (![fileManager isWritableFileAtPath:parentDirectoryPath]) {
        errorFormat = NSLocalizedStringFromTableInBundle(@"The privileges of the folder \"%@\" do not allow writing.", @"SysExLibrarian", SMBundleForObject(self), "format of error message if library file's folder can't be written");
    } else if (![fileManager isExecutableFileAtPath:parentDirectoryPath]) {
        errorFormat = NSLocalizedStringFromTableInBundle(@"The privileges of the folder \"%@\" do not allow searching.", @"SysExLibrarian", SMBundleForObject(self), "format of error message if library file's folder can't be searched");
    }

    if (errorFormat) {
        return [NSString stringWithFormat:errorFormat, [parentDirectoryPath lastPathComponent]];
    }
    
    // Now check the actual file, if it exists.

    BOOL isDirectory;
    if ([fileManager fileExistsAtPath:libraryFilePath isDirectory:&isDirectory]) {
        NSDictionary *libraryDictionary;

        if (isDirectory) {
            return NSLocalizedStringFromTableInBundle(@"There is a folder where the file should be.", @"SysExLibrarian", SMBundleForObject(self), "error message if library file is really a directory");
        }

        if (![fileManager isReadableFileAtPath:libraryFilePath]) {
            return NSLocalizedStringFromTableInBundle(@"The file's privileges do not allow reading.", @"SysExLibrarian", SMBundleForObject(self), "error message if library file isn't readable");
        }

        if (![fileManager isWritableFileAtPath:libraryFilePath]) {
            return NSLocalizedStringFromTableInBundle(@"The file's privileges do not allow writing.", @"SysExLibrarian", SMBundleForObject(self), "error message if library file isn't writable");
        }

        // TODO at this point the file could be an alias. should try resolving it, and if we get a different path, then loop
        //      try not to get caught in an alias loop, too

        libraryDictionary = [NSDictionary dictionaryWithContentsOfFile:libraryFilePath];
        if (!libraryDictionary) {
            return NSLocalizedStringFromTableInBundle(@"The file could not be read.", @"SysExLibrarian", SMBundleForObject(self), "error message if library file can't be read");
        }
    }

    // Everything is fine.
    return nil;
}

- (NSString *)preflightFileDirectory
{
    // Make sure the file directory exists.  If it isn't there, try to create it.

    NSString *fileDirectoryPath;
    NSFileManager *fileManager;
    BOOL isDirectory;

    fileDirectoryPath = [self fileDirectoryPath];
    fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:fileDirectoryPath isDirectory:&isDirectory]) {
        if (!isDirectory)
            return NSLocalizedStringFromTableInBundle(@"There is a file where the folder should be.", @"SysExLibrarian", SMBundleForObject(self), "error message if sysex file directory is really a file");

        if (![fileManager isReadableFileAtPath:fileDirectoryPath])
            return NSLocalizedStringFromTableInBundle(@"The folder's privileges do not allow reading.", @"SysExLibrarian", SMBundleForObject(self), "error message if sysex file directory isn't readable");

        if (![fileManager isWritableFileAtPath:fileDirectoryPath])
            return NSLocalizedStringFromTableInBundle(@"The folder's privileges do not allow writing.", @"SysExLibrarian", SMBundleForObject(self), "error message if sysex file directory isn't writable");
        
        if (![fileManager isExecutableFileAtPath:fileDirectoryPath])
            return NSLocalizedStringFromTableInBundle(@"The folder's privileges do not allow searching.", @"SysExLibrarian", SMBundleForObject(self), "error message if sysex file directory isn't searchable");
    } else {
        // The directory doesn't exist. Try to create it.        
        NSString *bogusFilePath = [fileDirectoryPath stringByAppendingPathComponent:@"file"];
        @try {
            [fileManager SSE_createPathToFile:bogusFilePath attributes:nil];
        }
        @catch (NSException *localException) {
            NSString *format = NSLocalizedStringFromTableInBundle(@"The folder %@ could not be created.\n%@", @"SysExLibrarian", SMBundleForObject(self), "error message if sysex file directory can't be created");
            return [NSString stringWithFormat:format, fileDirectoryPath, [localException reason]];
        }

        // We succeeded in creating the directory, so now update the alias we have saved.
        [self setFileDirectoryPath:fileDirectoryPath];
    }
        
    // Everything is fine.
    return nil;
}

- (void)loadEntries
{
    // We should only be called once at startup
    SMAssert([entries count] == 0);

    // NOTE: We don't do much error checking here; that should have already been taken care of in -preflightLibrary.
    // (Of course something could have changed since then and now, but that's pretty unlikely.)

    NSString *libraryFilePath = [self libraryFilePath];
    libraryFilePath = [libraryFilePath SSE_stringByResolvingSymlinksAndAliases];

    NSDictionary *libraryDictionary = [NSDictionary dictionaryWithContentsOfFile:libraryFilePath];
    NSArray *entryDicts = [libraryDictionary objectForKey:@"Entries"];
    for (NSDictionary *entryDict in entryDicts) {
        SSELibraryEntry *entry = [[SSELibraryEntry alloc] initWithLibrary:self dictionary:entryDict];
        if (entry) {
            [entries addObject:entry];
        }
        [entry release];
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
