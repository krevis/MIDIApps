#import "NSWorkspace-Extensions.h"

#import <Carbon/Carbon.h>


@implementation NSWorkspace (SSEExtensions)

- (BOOL)moveFileToTrash:(NSString *)path;
{
    // Send an AppleEvent to the Finder to move the file to the trash.
    // This is a workaround for bugs in -[NSWorkspace performFileOperation:NSWorkspaceRecycleOperation ...].
    // Wheee.

    OSErr err;
    AppleEvent event, reply;
    AEAddressDesc finderAddress;
    AEDesc targetDesc;
    OSType finderCreator = 'MACS';
    FSRef fsRef;
    AliasHandle aliasHandle;
    
    // Set up locals
    AECreateDesc(typeNull, NULL, 0, &event);
    AECreateDesc(typeNull, NULL, 0, &finderAddress);
    AECreateDesc(typeNull, NULL, 0, &reply);
    AECreateDesc(typeNull, NULL, 0, &targetDesc);
        
    // Create an event targeting the Finder
    err = AECreateDesc(typeApplSignature, (Ptr)&finderCreator, sizeof(finderCreator), &finderAddress);
    if (err != noErr) goto bail;

    err = AECreateAppleEvent(kAECoreSuite, kAEDelete, &finderAddress, kAutoGenerateReturnID, kAnyTransactionID, &event);
    if (err != noErr) goto bail;

    // Create the descriptor of the file to delete
    // (This needs to be an alias--if you use AECreateDesc(typeFSRef,...) it won't work.)
    err = FSPathMakeRef((const unsigned char *)[path fileSystemRepresentation], &fsRef, NULL);
    if (err != noErr) goto bail;

    err = FSNewAliasMinimal(&fsRef, &aliasHandle);
    if (err != noErr) goto bail;

    err = AECreateDesc(typeAlias, *aliasHandle, GetHandleSize((Handle)aliasHandle), &targetDesc);
    if (err != noErr) goto bail;

    DisposeHandle((Handle)aliasHandle);

    // Add the file descriptor to the apple event
    err = AEPutParamDesc(&event, keyDirectObject, &targetDesc);
    if (err != noErr) goto bail;

    // Send the event to the Finder
    err = AESend(&event, &reply, kAENoReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);

    // Clean up and leave
bail:
    AEDisposeDesc(&targetDesc);
    AEDisposeDesc(&event);
    AEDisposeDesc(&finderAddress);
    AEDisposeDesc(&reply);

    return (err == noErr);
}

@end
