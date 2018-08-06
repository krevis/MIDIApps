/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>

@class BDAlias;
@class SSELibrary;


@interface SSELibraryEntry : NSObject
{
    SSELibrary *nonretainedLibrary;

    NSString *name;
    BDAlias *alias;

    // Caches of file information
    NSString *manufacturer;
    NSNumber *sizeNumber;
    NSNumber *messageCountNumber;
	NSNumber *programNumber;    // 0 - 127
	
    struct {
        unsigned int isFilePresent:1;
        unsigned int hasLookedForFile:1;
    } flags;
}

- (id)initWithLibrary:(SSELibrary *)library;
- (id)initWithLibrary:(SSELibrary *)library dictionary:(NSDictionary *)dict;

- (SSELibrary *)library;

- (NSDictionary *)dictionaryValues;

- (NSString *)path;
- (void)setPath:(NSString *)value;

- (NSString *)name;
- (void)setName:(NSString *)value;
- (void)setNameFromFile;
- (BOOL)renameFileTo:(NSString *)newFileName;

- (NSArray *)messages;

// Derived information (comes from messages, but gets cached in the entry)

- (NSString *)manufacturer;
- (NSNumber *)size;
- (NSNumber *)messageCount;
- (BOOL)isFilePresent;
- (BOOL)isFilePresentIgnoringCachedValue;

- (BOOL)isFileInLibraryFileDirectory;

- (void)setProgramNumber:(NSNumber *)value;
- (NSNumber *)programNumber;

@end

// Notifications
extern NSString *SSELibraryEntryNameDidChangeNotification;
