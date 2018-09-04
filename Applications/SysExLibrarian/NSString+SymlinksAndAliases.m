//
//  NSString+SymlinksAndAliases.m
//  ResolvePath
//
//  Created by Matt Gallagher on 2010/02/22.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#if !__has_feature(objc_arc)
#error This file requires ARC.
#endif

#import "NSString+SymlinksAndAliases.h"
#include <sys/stat.h>

@implementation NSString (SSE_SymlinksAndAliases)

//
// stringByResolvingSymlinksAndAliases
//
// Tries to make a standardized, absolute path from the current string,
// resolving any aliases or symlinks in the path.
//
// returns the fully resolved path (if possible) or nil (if resolution fails)
//
- (NSString *)SSE_stringByResolvingSymlinksAndAliases
{
	//
	// Convert to a standardized absolute path.
	//
	NSString *path = [self stringByStandardizingPath];
	if (![path hasPrefix:@"/"]) {
		return nil;
	}
	
	//
	// Break into components. First component ("/") needs no resolution, so
	// we only need to handle subsequent components.
	//
	NSArray *pathComponents = [path pathComponents];
	NSString *resolvedPath = [pathComponents objectAtIndex:0];
	pathComponents = [pathComponents subarrayWithRange:NSMakeRange(1, [pathComponents count] - 1)];

	//
	// Process all remaining components.
	//
	for (NSString *component in pathComponents) {
		resolvedPath = [resolvedPath stringByAppendingPathComponent:component];
		resolvedPath = [resolvedPath SSE_stringByIterativelyResolvingSymlinkOrAlias];
        if (!resolvedPath) {
			return nil;
		}
	}

	return resolvedPath;
}

//
// stringByIterativelyResolvingSymlinkOrAlias
//
// Resolves the path where the final component could be a symlink and any
// component could be an alias.
//
// returns the resolved path
//
- (NSString *)SSE_stringByIterativelyResolvingSymlinkOrAlias
{
	NSString *path = self;
	NSString *aliasTarget = nil;
	struct stat fileInfo;
	
	//
	// Use lstat to determine if the file is a symlink
	//
    if (lstat([path fileSystemRepresentation], &fileInfo) < 0) {
		return nil;
	}
	
	//
	// While the file is a symlink or we can resolve aliases in the path,
	// keep resolving.
	//
	while (S_ISLNK(fileInfo.st_mode) ||
		(!S_ISDIR(fileInfo.st_mode) && (aliasTarget = [path SSE_stringByConditionallyResolvingAlias]))) {
        if (S_ISLNK(fileInfo.st_mode)) {
			//
			// Resolve the symlink final component in the path
			//
			NSString *symlinkPath = [path SSE_stringByConditionallyResolvingSymlink];
            if (!symlinkPath) {
				return nil;
			}
			path = symlinkPath;
		}
        else {
			path = aliasTarget;
		}

		//
		// Use lstat to determine if the file is a symlink
		//
        if (lstat([path fileSystemRepresentation], &fileInfo) < 0) {
			path = nil;
			continue;
		}
	}
	
	return path;
}

//
// stringByResolvingAlias
//
// Attempts to resolve the single alias at the end of the path.
//
// returns the resolved alias or self if path wasn't an alias or couldn't be
//	resolved.
//
- (NSString *)SSE_stringByResolvingAlias
{
    return [self SSE_stringByConditionallyResolvingAlias] ?: self;
}

//
// stringByResolvingSymlink
//
// Attempts to resolve the single symlink at the end of the path.
//
// returns the resolved path or self if path wasn't a symlink or couldn't be
//	resolved.
//
- (NSString *)SSE_stringByResolvingSymlink
{
    return [self SSE_stringByConditionallyResolvingSymlink] ?: self;
}

//
// stringByConditionallyResolvingSymlink
//
// Attempt to resolve the symlink pointed to by the path.
//
// returns the resolved path (if it was a symlink and resolution is possible)
//	otherwise nil
//
- (NSString *)SSE_stringByConditionallyResolvingSymlink
{
	//
	// Resolve the symlink final component in the path
	//
	NSString *symlinkPath = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:self error:NULL];
	if (!symlinkPath) {
		return nil;
	}
	if (![symlinkPath hasPrefix:@"/"]) {
		//
		// For relative path symlinks (common case), remove the
		// relative links
		//
		symlinkPath = [[self stringByDeletingLastPathComponent] stringByAppendingPathComponent:symlinkPath];
		symlinkPath = [symlinkPath stringByStandardizingPath];
	}
	return symlinkPath;
}

//
// stringByConditionallyResolvingAlias
//
// Attempt to resolve the alias pointed to by the path.
//
// returns the resolved path (if it was an alias and resolution is possible)
//	otherwise nil
//
- (NSString *)SSE_stringByConditionallyResolvingAlias
{
	NSString *resolvedPath = nil;

    NSURL *url = [NSURL fileURLWithPath:self isDirectory:NO];
	if (url) {
        // TODO Use [NSURL URLByResolvingAliasFileAtURL:url options:NSURLBookmarkResolutionWithoutUI error:NULL] after 10.10.
        //      Slightly more convenient.

        NSData* bookmarkData = [NSURL bookmarkDataWithContentsOfURL:url error:NULL];
        if (bookmarkData) {
            NSURL* resolvedURL = [NSURL URLByResolvingBookmarkData:bookmarkData options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:NULL error:NULL];
            if (resolvedURL && [resolvedURL isFileURL]) {
                resolvedPath = resolvedURL.path;
            }
        }
	}
	 
	return resolvedPath;
}

@end
