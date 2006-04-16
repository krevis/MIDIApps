/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSWorkspace-Extensions.h"

#import <Carbon/Carbon.h>


@implementation NSWorkspace (SSEExtensions)

static BOOL moveFilesToTrashViaNSWorkspace(NSArray *filePaths, NSWorkspace *workspace);
static BOOL moveFilesToTrashViaAppleEvent(NSArray *filePaths);

- (BOOL)SSE_moveFilesToTrash:(NSArray *)filePaths;
{
    // Workaround NSWorkspace bug if we are on 10.1 or earlier
    if (NSAppKitVersionNumber <= NSAppKitVersionNumber10_1)
        return moveFilesToTrashViaAppleEvent(filePaths);
    else
        return moveFilesToTrashViaNSWorkspace(filePaths, self);
}

BOOL moveFilesToTrashViaNSWorkspace(NSArray *filePaths, NSWorkspace *workspace)
{
    // Tell NSWorkspace to send each file individually to the trash.
    // Doing this is annoying--multiple files can be specified at one time
    // but they must all be in exactly the same directory. So we just do each one individually.
    unsigned int filePathCount, filePathIndex;

    filePathCount = [filePaths count];
    for (filePathIndex = 0; filePathIndex < filePathCount; filePathIndex++) {
        NSString *filePath;
        NSString *sourceDirectory;
        NSString *fileName;
        BOOL success;
        int tag;

        filePath = [filePaths objectAtIndex:filePathIndex];
        sourceDirectory = [filePath stringByDeletingLastPathComponent];
        fileName = [filePath lastPathComponent];

        success = [workspace performFileOperation:NSWorkspaceRecycleOperation source:sourceDirectory destination:nil files:[NSArray arrayWithObject:fileName] tag:&tag];
        // NOTE: According to the docs, we should pass in @"" for destination, but that causes an exception to be raised under Mac OS X 10.2.
        if (!success)
            return NO;
    }

    return YES;
}

BOOL moveFilesToTrashViaAppleEvent(NSArray *filePaths)
{
    // Send an AppleEvent to the Finder to move the files to the trash.
    // NOTE: This does not work correctly if any of the file paths point to symlinks. The FSRef that we create points to
    // the target of the symlink, not the symlink itself--and this happens transparently so I'm not sure anything
    // can be done about it. Lame.

    OSErr err;
    AppleEvent event, reply;
    AEAddressDesc finderAddress;
    AEDescList targetListDesc;
    OSType finderCreator = 'MACS';
    unsigned int filePathCount, filePathIndex;
    FSRef fsRef;
    AliasHandle aliasHandle;
    
    // Set up locals
    AECreateDesc(typeNull, NULL, 0, &event);
    AECreateDesc(typeNull, NULL, 0, &finderAddress);
    AECreateDesc(typeNull, NULL, 0, &reply);
    AECreateDesc(typeNull, NULL, 0, &targetListDesc);
        
    // Create an event targeting the Finder
    err = AECreateDesc(typeApplSignature, (Ptr)&finderCreator, sizeof(finderCreator), &finderAddress);
    if (err != noErr) goto bail;

    err = AECreateAppleEvent(kAECoreSuite, kAEDelete, &finderAddress, kAutoGenerateReturnID, kAnyTransactionID, &event);
    if (err != noErr) goto bail;

    err = AECreateList(NULL, 0, false, &targetListDesc);
    if (err != noErr) goto bail;

    filePathCount = [filePaths count];
    for (filePathIndex = 0; filePathIndex < filePathCount; filePathIndex++) {
        NSString *filePath;

        filePath = [filePaths objectAtIndex:filePathIndex];

        // Create the descriptor of the file to delete
        // (This needs to be an alias--if you use AECreateDesc(typeFSRef,...) it won't work, since FSRefs are not valid across application boundaries.)
        err = FSPathMakeRef((const unsigned char *)[filePath fileSystemRepresentation], &fsRef, NULL);
        if (err != noErr) goto bail;

        err = FSNewAliasMinimal(&fsRef, &aliasHandle);
        if (err != noErr) goto bail;

        // Then add the alias to the descriptor list
        HLock((Handle)aliasHandle);
        err = AEPutPtr(&targetListDesc, 0, typeAlias, *aliasHandle, GetHandleSize((Handle)aliasHandle));
        HUnlock((Handle)aliasHandle);

        DisposeHandle((Handle)aliasHandle);

        if (err != noErr) goto bail;
    }

    // Add the file descriptor list to the apple event
    err = AEPutParamDesc(&event, keyDirectObject, &targetListDesc);
    if (err != noErr) goto bail;
    
    // Send the event to the Finder
    err = AESend(&event, &reply, kAENoReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);

    // Clean up and leave
bail:
    AEDisposeDesc(&targetListDesc);
    AEDisposeDesc(&event);
    AEDisposeDesc(&finderAddress);
    AEDisposeDesc(&reply);

    return (err == noErr);
}

@end
