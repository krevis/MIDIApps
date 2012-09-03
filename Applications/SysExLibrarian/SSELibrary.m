/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSELibrary.h"

#import <Carbon/Carbon.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSELibraryEntry.h"
#import "BDAlias.h"
#import "NSFileManager-Extensions.h"
#import "NSWorkspace-Extensions.h"


@interface SSELibrary (Private)

- (NSString *)findFolder:(OSType)folderType;
- (NSString *)resolveAliasesInPath:(NSString *)path;

- (NSString *)defaultFileDirectoryPath;

- (NSString *)preflightLibrary;
- (NSString *)preflightFileDirectory;
- (void)loadEntries;

- (NSArray *)fileTypesFromDocumentTypeDictionary:(NSDictionary *)documentTypeDict;

- (NSDictionary *)entriesByFilePath;

- (void)postEntryWillBeRemovedNotificationForEntry:(SSELibraryEntry *)entry;

@end


@implementation SSELibrary

NSString *SSELibraryDidChangeNotification = @"SSELibraryDidChangeNotification";
NSString *SSELibraryEntryWillBeRemovedNotification = @"SSELibraryEntryWillBeRemovedNotification";

NSString *SSELibraryFileDirectoryAliasPreferenceKey = @"SSELibraryFileDirectoryAlias";
NSString *SSELibraryFileDirectoryPathPreferenceKey = @"SSELibraryFileDirectoryPath";

const FourCharCode SSEApplicationCreatorCode = 'SnSX';
const FourCharCode SSELibraryFileTypeCode = 'sXLb';
const FourCharCode SSESysExFileTypeCode = 'sysX';
NSString *SSESysExFileExtension = @"syx";

+ (SSELibrary *)sharedLibrary;
{
    static SSELibrary *sharedLibrary = nil;

    if (!sharedLibrary) {
        sharedLibrary = [[self alloc] init];
    }

    return sharedLibrary;
}

- (id)init;
{
    NSArray *documentTypes;

    if (!(self = [super init]))
        return nil;

    documentTypes = [[SMBundleForObject(self) infoDictionary] objectForKey:@"CFBundleDocumentTypes"];
    if ([documentTypes count] > 0) {
        NSDictionary *documentTypeDict;

        documentTypeDict = [documentTypes objectAtIndex:0];
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

- (void)dealloc;
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

- (NSString *)libraryFilePath;
{
    static NSString *libraryFilePath = nil;

    if (!libraryFilePath) {
        NSString *preferencesFolderPath;

        preferencesFolderPath = [self findFolder:kPreferencesFolderType];
        // That shouldn't have failed, but let's be sure...
        if (!preferencesFolderPath) {
            NSArray *paths;
            NSString *homeLibraryPath;

            paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
            // That shouldn't have failed either, but who knows what could happen?
            if ([paths count] > 0)
                homeLibraryPath = [paths objectAtIndex:0];
            else
                homeLibraryPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];  // Fall back to hard-coded version

            preferencesFolderPath = [homeLibraryPath stringByAppendingPathComponent:@"Preferences"];
        }

        preferencesFolderPath = [self resolveAliasesInPath:preferencesFolderPath];        
        libraryFilePath = [preferencesFolderPath stringByAppendingPathComponent:@"SysEx Librarian Library.sXLb"];
        libraryFilePath = [self resolveAliasesInPath:libraryFilePath];
        [libraryFilePath retain];
    }

    return libraryFilePath;
}

- (NSString *)libraryFilePathForDisplay;
{
    return [[self libraryFilePath] stringByDeletingPathExtension];
}

- (NSString *)fileDirectoryPath;
{
    NSData *aliasData;
    NSString *path = nil;

    aliasData = [[NSUserDefaults standardUserDefaults] dataForKey:SSELibraryFileDirectoryAliasPreferenceKey];
    if (aliasData) {    
        path = [[BDAlias aliasWithData:aliasData] fullPath];
        if (path) {
            // Make sure the saved path is in sync with what the alias resolved
            [[NSUserDefaults standardUserDefaults] setObject:path forKey:SSELibraryFileDirectoryPathPreferenceKey];
        } else {
            // Couldn't resolve the alias, so fall back to the path (which may not exist yet)
            path = [[NSUserDefaults standardUserDefaults] stringForKey:SSELibraryFileDirectoryPathPreferenceKey];
        }
    }

    if (!path)
        path = [self defaultFileDirectoryPath];

    path = [self resolveAliasesInPath:path];

    return path;
}

- (void)setFileDirectoryPath:(NSString *)newPath;
{
    BDAlias *alias;

    if (!newPath)
        newPath = [self defaultFileDirectoryPath];
    
    alias = [BDAlias aliasWithPath:newPath];
    SMAssert([alias fullPath] != nil);

    [[NSUserDefaults standardUserDefaults] setObject: [alias aliasData] forKey: SSELibraryFileDirectoryAliasPreferenceKey];
    [[NSUserDefaults standardUserDefaults] setObject: newPath forKey: SSELibraryFileDirectoryPathPreferenceKey];
}

- (BOOL)isPathInFileDirectory:(NSString *)path;
{
    return [path hasPrefix:[[self fileDirectoryPath] stringByAppendingString:@"/"]];
}

- (NSString *)preflightAndLoadEntries;
{
    NSString *errorMessage;

    if ((errorMessage = [self preflightLibrary])) {
        NSString *format;

        format = NSLocalizedStringFromTableInBundle(@"There is a problem accessing the library \"%@\".\n%@", @"SysExLibrarian", SMBundleForObject(self), "error message if library file can't be read (preflight)");
        return [NSString stringWithFormat:format, [self libraryFilePathForDisplay], errorMessage];
    }

    if ((errorMessage = [self preflightFileDirectory])) {
        NSString *format;

        format = NSLocalizedStringFromTableInBundle(@"There is a problem accessing the SysEx files folder \"%@\".\n%@", @"SysExLibrarian", SMBundleForObject(self), "error message if SysEx files folder can't be accessed (preflight)");
        return [NSString stringWithFormat:format, [self fileDirectoryPath], errorMessage];
    }

    [self loadEntries];
    return nil;
}

- (NSArray *)entries;
{
    return entries;
}

- (SSELibraryEntry *)addEntryForFile:(NSString *)filePath;
{
    SSELibraryEntry *entry;
    BOOL wasDirty;

    // Setting the entry path and name will cause us to be notified of a change, and we'll autosave.
    // However, the add might not succeed--if it doesn't, make sure our dirty flag isn't set if it shouldn't be.

    wasDirty = flags.isDirty;

    entry = [[SSELibraryEntry alloc] initWithLibrary:self];
    [entry setPath:filePath];

    if ([[entry messages] count] > 0) {
        [entry setNameFromFile];
        [entries addObject:entry];
        [entry release];
    } else {
        [entry release];
        entry = nil;
        if (!wasDirty)
            flags.isDirty = NO;
    }
    
    return entry;
}

- (SSELibraryEntry *)addNewEntryWithData:(NSData *)sysexData;
{
    NSFileManager *fileManager;
    NSString *newFileName;
    NSString *newFilePath;
    NSDictionary *newFileAttributes;
    SSELibraryEntry *entry = nil;

    fileManager = [NSFileManager defaultManager];

    newFileName = NSLocalizedStringFromTableInBundle(@"Untitled", @"SysExLibrarian", SMBundleForObject(self), "name of new sysex file");
    newFilePath = [[[self fileDirectoryPath] stringByAppendingPathComponent:newFileName] stringByAppendingPathExtension:SSESysExFileExtension];
    newFilePath = [fileManager SSE_uniqueFilenameFromName:newFilePath];

    [fileManager SSE_createPathToFile:newFilePath attributes:nil];
    // NOTE This will raise an NSGenericException if it fails

    newFileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedLong:SSESysExFileTypeCode], NSFileHFSTypeCode,
        [NSNumber numberWithUnsignedLong:SSEApplicationCreatorCode], NSFileHFSCreatorCode,
        [NSNumber numberWithBool:YES], NSFileExtensionHidden, nil];

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

- (void)removeEntry:(SSELibraryEntry *)entry;
{
    NSUInteger entryIndex;

    entryIndex = [entries indexOfObjectIdenticalTo:entry];
    if (entryIndex != NSNotFound) {
        [self postEntryWillBeRemovedNotificationForEntry:[entries objectAtIndex:entryIndex]];
        [entries removeObjectAtIndex:entryIndex];

        [self noteEntryChanged];
    }
}

- (void)removeEntries:(NSArray *)entriesToRemove;
{
    unsigned int entryIndex;

    entryIndex = [entriesToRemove count];
    while (entryIndex--) {
        SSELibraryEntry *entry = [entriesToRemove objectAtIndex:entryIndex];
        [self postEntryWillBeRemovedNotificationForEntry:entry];
    }

    [entries SnoizeMIDI_removeObjectsIdenticalToObjectsInArray:entriesToRemove];

    [self noteEntryChanged];
}

- (void)noteEntryChanged;
{
    flags.isDirty = YES;
    [self autosave];
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:SSELibraryDidChangeNotification object:self] postingStyle:NSPostWhenIdle];
}

- (void)autosave;
{
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(save) object: nil];
    [self performSelector: @selector(save) withObject: nil afterDelay: 0.0];
}

- (void)save;
{
    if (!flags.isDirty)
        return;    
    
    NSMutableDictionary *dictionary;
    NSMutableArray *entryDicts;
    unsigned int entryCount, entryIndex;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *libraryFilePath = [self libraryFilePath];
    NSDictionary *fileAttributes;
    NSString *errorMessage = nil;
    NSData *fileData;

    dictionary = [NSMutableDictionary dictionary];
    entryDicts = [NSMutableArray array];

    entryCount = [entries count];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        NSDictionary *entryDict;

        entryDict = [[entries objectAtIndex:entryIndex] dictionaryValues];
        if (entryDict)
            [entryDicts addObject:entryDict];
    }

    [dictionary setObject:entryDicts forKey:@"Entries"];

    fileData = [NSPropertyListSerialization dataFromPropertyList:dictionary format:NSPropertyListXMLFormat_v1_0 errorDescription:&errorMessage];
    if (errorMessage) {
        [errorMessage autorelease]; // docs say we're supposed to release this string, oddly enough
    } else {    
        NS_DURING {
            [fileManager SSE_createPathToFile:libraryFilePath attributes:nil];
        } NS_HANDLER {
            errorMessage = [[[localException reason] retain] autorelease];
        } NS_ENDHANDLER;
    }

    if (!errorMessage) {
        fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedLong:SSELibraryFileTypeCode], NSFileHFSTypeCode,
            [NSNumber numberWithUnsignedLong:SSEApplicationCreatorCode], NSFileHFSCreatorCode,
            [NSNumber numberWithBool:YES], NSFileExtensionHidden, nil];
        
        if (![fileManager createFileAtPath:libraryFilePath contents:fileData attributes:fileAttributes])
            errorMessage = NSLocalizedStringFromTableInBundle(@"The file could not be written.", @"SysExLibrarian", SMBundleForObject(self), "error message if sysex file can't be written");
    }

    if (errorMessage) {
        NSString *title, *messageFormat;

        title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
        messageFormat = NSLocalizedStringFromTableInBundle(@"The library \"%@\" could not be saved.\n%@", @"SysExLibrarian", SMBundleForObject(self), "format of error message if the library file can't be saved");
        
        NSRunCriticalAlertPanel(title, messageFormat, nil, nil, nil, libraryFilePath, errorMessage);
        // NOTE This is not fantastic UI, but it basically works.  This should not happen unless the user is trying to provoke us, anyway.
    } else {
        flags.isDirty = NO;
    }
}

- (NSArray *)allowedFileTypes;
{
    return allowedFileTypes;
}

- (SSELibraryFileType)typeOfFileAtPath:(NSString *)filePath;
{
    NSString *fileType;

    if (!filePath || [filePath length] == 0) {
        return SSELibraryFileTypeUnknown;
    }
    
    fileType = [filePath pathExtension];
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

- (NSArray *)findEntriesForFiles:(NSArray *)filePaths returningNonMatchingFiles:(NSArray **)nonMatchingFilePathsPtr;
{
    NSDictionary *entriesByFilePath;
    NSMutableArray *nonMatchingFilePaths;
    NSMutableArray *matchingEntries;
    unsigned int filePathIndex, filePathCount;

    entriesByFilePath = [self entriesByFilePath];

    filePathCount = [filePaths count];
    if (nonMatchingFilePathsPtr)
        nonMatchingFilePaths = [NSMutableArray arrayWithCapacity:filePathCount];
    else
        nonMatchingFilePaths = nil;
    matchingEntries = [NSMutableArray arrayWithCapacity:filePathCount];

    for (filePathIndex = 0; filePathIndex < filePathCount; filePathIndex++) {
        NSString *filePath;
        SSELibraryEntry *entry;

        filePath = [filePaths objectAtIndex:filePathIndex];

        entry = [entriesByFilePath objectForKey:filePath];
        if (entry)
            [matchingEntries addObject:entry];
        else
            [nonMatchingFilePaths addObject:filePath];
    }
        
    if (nonMatchingFilePathsPtr)
        *nonMatchingFilePathsPtr = nonMatchingFilePaths;

    return matchingEntries;
}

- (BOOL)moveFilesInLibraryDirectoryToTrashForEntries:(NSArray *)entriesToTrash;
{
    unsigned int entryCount, entryIndex;
    NSMutableArray *filesToTrash;

    entryCount = [entriesToTrash count];
    filesToTrash = [NSMutableArray arrayWithCapacity:entryCount];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        SSELibraryEntry *entry;

        entry = [entriesToTrash objectAtIndex:entryIndex];
        if ([entry isFileInLibraryFileDirectory])
            [filesToTrash addObject:[entry path]];
    }

    if ([filesToTrash count] > 0)
        return [[NSWorkspace sharedWorkspace] SSE_moveFilesToTrash:filesToTrash];
    else
        return YES;
}

@end


@implementation SSELibrary (Private)

- (NSString *)findFolder:(OSType)folderType;
{
    OSErr error;
    FSRef folderFSRef;
    NSString *path = nil;

    error = FSFindFolder(kUserDomain, folderType, kCreateFolder, &folderFSRef);
    if (error == noErr) {
        CFURLRef url;

        url = CFURLCreateFromFSRef(kCFAllocatorDefault, &folderFSRef);
        if (url) {
            path = [(NSString *)CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle) autorelease];
            CFRelease(url);
        }
    }

    return path;    
}

- (NSString *)resolveAliasesInPath:(NSString *)path
{
    // NOTE This only works if all components in the path actually exist.
    // (And it's not possible to determine that ahead of time, since any component could be an alias...)
    // If any errors occur, the original path will be returned.
    
    NSString *resolvedPath = nil;
    CFURLRef url;

    url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, false);
    if (url) {
        FSRef fsRef;

        if (CFURLGetFSRef(url, &fsRef)) {
            Boolean targetIsFolder, wasAliased;

            if (FSResolveAliasFile(&fsRef, true, &targetIsFolder, &wasAliased) == noErr && wasAliased) {
                CFURLRef resolvedURL;

                resolvedURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &fsRef);
                if (resolvedURL) {
                    resolvedPath = (NSString*)CFURLCopyFileSystemPath(resolvedURL, kCFURLPOSIXPathStyle);
                    CFRelease(resolvedURL);
                }
            }
        }

        CFRelease(url);
    }

    if (!resolvedPath)
        resolvedPath = [path copy];

    return [resolvedPath autorelease];
}

- (NSString *)defaultFileDirectoryPath;
{
    NSString *documentsFolderPath;

    documentsFolderPath = [self findFolder:kDocumentsFolderType];
    if (!documentsFolderPath) {
        // Fall back to hard-coding it
        documentsFolderPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    }

    documentsFolderPath = [self resolveAliasesInPath:documentsFolderPath];
    documentsFolderPath = [documentsFolderPath stringByAppendingPathComponent:@"SysEx Librarian"];

    return documentsFolderPath;
}

- (NSString *)preflightLibrary;
{
    // Check that the library file can be read and written.

    NSString *libraryFilePath;
    NSFileManager *fileManager;
    NSString *parentDirectoryPath;
    BOOL isDirectory;
    NSString *errorFormat = nil;

    libraryFilePath = [self libraryFilePath];
    fileManager = [NSFileManager defaultManager];
    
    // Try creating the path to the file, first.
    NS_DURING {
        [fileManager SSE_createPathToFile:libraryFilePath attributes:nil];
    } NS_HANDLER {
        return [localException reason];
    } NS_ENDHANDLER;

    // Then check that the file's parent directory is readable, writable, and searchable.
    parentDirectoryPath = [libraryFilePath stringByDeletingLastPathComponent];
    if (![fileManager isReadableFileAtPath:parentDirectoryPath]) {
        errorFormat = NSLocalizedStringFromTableInBundle(@"The privileges of the folder \"%@\" do not allow reading.", @"SysExLibrarian", SMBundleForObject(self), "format of error message if library file's folder can't be read");
    } else if (![fileManager isWritableFileAtPath:parentDirectoryPath]) {
        errorFormat = NSLocalizedStringFromTableInBundle(@"The privileges of the folder \"%@\" do not allow writing.", @"SysExLibrarian", SMBundleForObject(self), "format of error message if library file's folder can't be written");
    } else if (![fileManager isExecutableFileAtPath:parentDirectoryPath]) {
        errorFormat = NSLocalizedStringFromTableInBundle(@"The privileges of the folder \"%@\" do not allow searching.", @"SysExLibrarian", SMBundleForObject(self), "format of error message if library file's folder can't be searched");
    }

    if (errorFormat)
        return [NSString stringWithFormat:errorFormat, [parentDirectoryPath lastPathComponent]];
    
    // Now check the actual file, if it exists.
    if ([fileManager fileExistsAtPath:libraryFilePath isDirectory:&isDirectory]) {
        NSDictionary *libraryDictionary;

        if (isDirectory)
            return NSLocalizedStringFromTableInBundle(@"There is a folder where the file should be.", @"SysExLibrarian", SMBundleForObject(self), "error message if library file is really a directory");

        if (![fileManager isReadableFileAtPath:libraryFilePath])
            return NSLocalizedStringFromTableInBundle(@"The file's privileges do not allow reading.", @"SysExLibrarian", SMBundleForObject(self), "error message if library file isn't readable");

        if (![fileManager isWritableFileAtPath:libraryFilePath])
            return NSLocalizedStringFromTableInBundle(@"The file's privileges do not allow writing.", @"SysExLibrarian", SMBundleForObject(self), "error message if library file isn't writable");

        libraryDictionary = [NSDictionary dictionaryWithContentsOfFile:libraryFilePath];
        if (!libraryDictionary)
            return NSLocalizedStringFromTableInBundle(@"The file could not be read.", @"SysExLibrarian", SMBundleForObject(self), "error message if library file can't be read");
    }

    // Everything is fine.
    return nil;
}

- (NSString *)preflightFileDirectory;
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
        NSString *bogusFilePath;

        bogusFilePath = [fileDirectoryPath stringByAppendingPathComponent:@"file"];
        NS_DURING {
            [fileManager SSE_createPathToFile:bogusFilePath attributes:nil];
        } NS_HANDLER {
            NSString *format;

            format = NSLocalizedStringFromTableInBundle(@"The folder %@ could not be created.\n%@", @"SysExLibrarian", SMBundleForObject(self), "error message if sysex file directory can't be created");            
            return [NSString stringWithFormat:format, fileDirectoryPath, [localException reason]];
        } NS_ENDHANDLER;

        // We succeeded in creating the directory, so now update the alias we have saved.
        [self setFileDirectoryPath:fileDirectoryPath];
    }
        
    // Everything is fine.
    return nil;
}

- (void)loadEntries;
{
    NSString *libraryFilePath;
    NSDictionary *libraryDictionary = nil;
    NSArray *entryDicts;
    unsigned int entryDictIndex, entryDictCount;

    // We should only be called once at startup
    SMAssert([entries count] == 0);

    // NOTE: We don't do much error checking here; that should have already been taken care of in +performPreflightChecks.
    // (Of course something could have changed since then and now, but that's pretty unlikely.)

    libraryFilePath = [self libraryFilePath];
    libraryDictionary = [NSDictionary dictionaryWithContentsOfFile:libraryFilePath];

    entryDicts = [libraryDictionary objectForKey:@"Entries"];
    entryDictCount = [entryDicts count];
    for (entryDictIndex = 0; entryDictIndex < entryDictCount; entryDictIndex++) {
        NSDictionary *entryDict;
        SSELibraryEntry *entry;

        entryDict = [entryDicts objectAtIndex:entryDictIndex];
        entry = [[SSELibraryEntry alloc] initWithLibrary:self dictionary:entryDict];
        [entries addObject:entry];
        [entry release];
    }

    // Ignore any changes that came from reading entries
    flags.isDirty = NO;
}

- (NSArray *)fileTypesFromDocumentTypeDictionary:(NSDictionary *)documentTypeDict;
{
    NSMutableArray *fileTypes;
    NSArray *extensions;
    NSArray *osTypes;

    fileTypes = [NSMutableArray array];

    extensions = [documentTypeDict objectForKey:@"CFBundleTypeExtensions"];
    if (extensions && [extensions isKindOfClass:[NSArray class]]) {
        [fileTypes addObjectsFromArray:extensions];
    }

    osTypes = [documentTypeDict objectForKey:@"CFBundleTypeOSTypes"];
    if (osTypes && [osTypes isKindOfClass:[NSArray class]]) {
        unsigned int osTypeIndex, osTypeCount;

        osTypeCount = [osTypes count];
        for (osTypeIndex = 0; osTypeIndex < osTypeCount; osTypeIndex++) {
            [fileTypes addObject:[NSString stringWithFormat:@"'%@'", [osTypes objectAtIndex:osTypeIndex]]];
        }
    }

    return fileTypes;
}

- (NSDictionary *)entriesByFilePath;
{
    unsigned int entryIndex, entryCount;
    NSMutableDictionary *entriesByFilePath;

    entryCount = [entries count];
    entriesByFilePath = [NSMutableDictionary dictionaryWithCapacity:entryCount];
    for (entryIndex = 0; entryIndex < entryCount; entryIndex++) {
        SSELibraryEntry *entry;
        NSString *filePath;

        entry = [entries objectAtIndex:entryIndex];
        filePath = [entry path];
        if (filePath) {
            SMAssert([entriesByFilePath objectForKey:filePath] == nil);
            [entriesByFilePath setObject:entry forKey:filePath];
        }
    }

    return entriesByFilePath;
}

- (void)postEntryWillBeRemovedNotificationForEntry:(SSELibraryEntry *)entry;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSELibraryEntryWillBeRemovedNotification object:entry];
}

@end
