#import "NSWorkspace-Extensions.h"

#import <Carbon/Carbon.h>


@implementation NSWorkspace (SSEExtensions)

- (BOOL)moveFilesToTrash:(NSArray *)filePaths;
{
    // Send an AppleEvent to the Finder to move the files to the trash.
    // This is a workaround for bugs in -[NSWorkspace performFileOperation:NSWorkspaceRecycleOperation ...].
    // Wheee.

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
        // (This needs to be an alias--if you use AECreateDesc(typeFSRef,...) it won't work.)
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
