//
//  SSEAlias.m
//  SysExLibrarian
//
//  Created by Kurt Revis on 9/3/18.
//

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
