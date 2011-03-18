/*
 Copyright (c) 2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSFileManager-Extensions.h"


@implementation NSFileManager (SSEExtensions)

- (void) SSE_createPathToFile:(NSString *)newFilePath attributes:(NSDictionary*)attributes
{
    if (!newFilePath || [newFilePath length] == 0 || ![newFilePath isAbsolutePath]) {
        [NSException raise: NSGenericException format: @"Cannot create path to invalid file: '%@'.", newFilePath]; 
    }
    
    // Standardize the path and follow symlinks, so we won't hit any symlinks later on
    newFilePath = [[newFilePath stringByStandardizingPath] stringByResolvingSymlinksInPath];

    if (!newFilePath || [newFilePath length] == 0 || ![newFilePath isAbsolutePath]) {
        [NSException raise: NSGenericException format: @"Cannot create path to invalid file: '%@'.", newFilePath]; 
    }
    
    NSArray* components = [newFilePath pathComponents];
    unsigned int componentCount = [components count];
    
    if (componentCount <= 1) {
        [NSException raise: NSGenericException format: @"Cannot create path to invalid file: '%@'", newFilePath]; 
    }

    unsigned int componentIndex;
    NSString* partialPath = @"";
    NSString* failureReason = nil;
    for (componentIndex = 0; !failureReason && componentIndex < componentCount - 1; componentIndex++) {
        partialPath = [partialPath stringByAppendingPathComponent: [components objectAtIndex: componentIndex]];
        
        BOOL isDirectory;
        if ([self fileExistsAtPath: partialPath isDirectory: &isDirectory]) {
            if (isDirectory) {
                // OK, no problem, go on to the next component
            } else {
                // File already exists there, and isn't a symlink...
                failureReason = [NSString stringWithFormat: @"Cannot create path to file '%@' because an ordinary file already exists at '%@'.", newFilePath, partialPath];
            }            
        } else {
            // directory doesn't exist; try to create
            if (![self createDirectoryAtPath: partialPath withIntermediateDirectories:NO attributes: attributes error:NULL]) {
                failureReason = [NSString stringWithFormat: @"Cannot create path to file '%@' because the directory '%@' could not be created.", newFilePath, partialPath];
            }
        }
    }
        
    if (failureReason) {
        [NSException raise: NSGenericException format: @"%@", failureReason];
    }
}

- (NSString*) SSE_uniqueFilenameFromName: (NSString*) originalPath
{
    NSString* originalPathWithoutExtension = [originalPath stringByDeletingPathExtension];
    NSString* originalPathExtension = [originalPath pathExtension];

    NSString* testPath = originalPath;
    unsigned int suffix = 0;
    
    while ([self fileExistsAtPath: testPath])
    {
        suffix++;
        testPath = [[originalPathWithoutExtension stringByAppendingFormat: @"-%u", suffix] stringByAppendingPathExtension: originalPathExtension];
    }
    
    return testPath;
}

@end
