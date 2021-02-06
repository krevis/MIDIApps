/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>

@class SSELibraryEntry;


typedef NS_ENUM(NSInteger, SSELibraryFileType) {
    SSELibraryFileTypeRaw = 0,
    SSELibraryFileTypeStandardMIDI = 1,
    SSELibraryFileTypeUnknown = 2
};


@interface SSELibrary : NSObject

+ (SSELibrary *)sharedLibrary;

- (NSString *)libraryFilePath;

- (NSString *)fileDirectoryPath;
- (void)setFileDirectoryPath:(NSString *)newPath;
- (BOOL)isPathInFileDirectory:(NSString *)path;

- (NSString *)preflightAndLoadEntries;
    // Returns an error message if something critical is wrong

- (NSArray<SSELibraryEntry *> *)entries;

- (SSELibraryEntry *)addEntryForFile:(NSString *)filePath;
    // NOTE: This will return nil, and add no entry, if no messages are in the file

- (SSELibraryEntry *)addNewEntryWithData:(NSData *)sysexData error:(NSError **)error;

- (void)removeEntry:(SSELibraryEntry *)entry;
- (void)removeEntries:(NSArray<SSELibraryEntry *> *)entriesToRemove;

- (void)noteEntryChanged;
- (void)autosave;
- (void)save;

@property (nonatomic, readonly) NSArray<NSString *> *allowedFileTypes;
- (SSELibraryFileType)typeOfFileAtPath:(NSString *)filePath;

- (NSArray<SSELibraryEntry *> *)findEntriesForFiles:(NSArray *)filePaths returningNonMatchingFiles:(NSArray **)nonMatchingFilePathsPtr;

- (void)moveFilesInLibraryDirectoryToTrashForEntries:(NSArray<SSELibraryEntry *> *)entriesToTrash;

@end

// Notifications
extern NSNotificationName const SSELibraryDidChangeNotification;
extern NSNotificationName const SSELibraryEntryWillBeRemovedNotification;	// notification's object is the entry

// Preference keys
extern NSString * const SSELibraryFileDirectoryBookmarkPreferenceKey;
extern NSString * const SSELibraryFileDirectoryAliasPreferenceKey;
extern NSString * const SSELibraryFileDirectoryPathPreferenceKey;
