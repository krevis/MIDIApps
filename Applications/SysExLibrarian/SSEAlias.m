/*
 Copyright (c) 2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if !__has_feature(objc_arc)
#error This file requires ARC.
#endif

#import "SSEAlias.h"

@implementation SSEAlias {
    NSData* bookmarkData;
}

+ (SSEAlias *)aliasWithData:(NSData *)data
{
    return [[SSEAlias alloc] initWithData:data];
}

+ (SSEAlias *)aliasWithPath:(NSString *)path
{
    return [[SSEAlias alloc] initWithPath:path];
}

+ (SSEAlias *)aliasWithAliasRecordData:(NSData *)data
{
    return [[SSEAlias alloc] initWithAliasRecordData:data];
}

- (id)initWithData:(NSData *)data
{
    if ((self = [super init])) {
        if (data) {
            bookmarkData = data;
        }
        else {
            self = nil;
        }
    }

    return self;
}

- (id)initWithAliasRecordData:(NSData *)aliasRecordData
{
    NSData* bookmarkFromAliasData = nil;
    if (aliasRecordData){
        CFDataRef cfBookmarkData = CFURLCreateBookmarkDataFromAliasRecord(kCFAllocatorDefault, (__bridge CFDataRef)aliasRecordData);
        bookmarkFromAliasData = (NSData *)CFBridgingRelease(cfBookmarkData);
    }

    return [self initWithData:bookmarkFromAliasData];
}

- (id)initWithPath:(NSString *)path
{
    NSURL *url = [NSURL fileURLWithPath:path];
    NSData *data = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];
    return [self initWithData:data];
}

- (NSData *)data
{
    return bookmarkData;
}

- (NSString *)path
{
    return [self pathAllowingUI:YES];
}

- (NSString *)pathAllowingUI:(BOOL)allowUI
{
    NSString *fullPath = nil;

    NSURLBookmarkResolutionOptions options = allowUI ? 0 : NSURLBookmarkResolutionWithoutUI;
    BOOL isStale = NO;
    NSError *error = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmarkData options:options relativeToURL:nil bookmarkDataIsStale:&isStale error:&error];
    if (url && [url isFileURL]) {
        if (isStale) {
            // Replace stale data with fresh data
            NSData *data = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];
            if (data) {
                bookmarkData = data;
            }
        }

        fullPath = [url path];
    }

    return fullPath;
}

@end
