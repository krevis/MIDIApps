#import "NSWorkspace-Extensions.h"

#import <Carbon/Carbon.h>

#define TRASH_FILES_USING_FINDER 1


#if !TRASH_FILES_USING_FINDER

@interface NSWorkspace (SSEExtensions2)

- (BOOL)moveFileToTrash:(NSString *)filePath;

@end

#endif


@implementation NSWorkspace (SSEExtensions)

- (BOOL)moveFilesToTrash:(NSArray *)filePaths;
#if TRASH_FILES_USING_FINDER
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
#else
{
    // Find the trash for each file using Carbon, and then use NSFileManager to move each file there.
    unsigned int fileIndex, fileCount;

    fileCount = [filePaths count];
    for (fileIndex = 0; fileIndex < fileCount; fileIndex++) {
        if ([self moveFileToTrash:[filePaths objectAtIndex:fileIndex]] == NO)
            return NO;
    }

    return YES;
}
#endif


#if !TRASH_FILES_USING_FINDER

static OSErr PathToFSRef(CFStringRef inPath, FSRef *outRef);
static CFStringRef FSRefToPathCopy(const FSRef *inRef);

static NSString *trashPathForFile(NSString *filePath);
static NSString *destinationNameForFileInTrash(NSString *fileName, NSString *trashPath);
static void notifyThatTrashChanged(NSString *trashPath);

- (BOOL)moveFileToTrash:(NSString *)filePath;
{
    NSString *trashPath;
    NSString *fileName;
    NSString *destinationName;
    NSString *destinationPath;

    trashPath = trashPathForFile(filePath);
    if (!trashPath)
        return NO;

    fileName = [filePath lastPathComponent];

    destinationName = destinationNameForFileInTrash(fileName, trashPath);

    destinationPath = [trashPath stringByAppendingPathComponent:destinationName];

    if (![[NSFileManager defaultManager] movePath:filePath toPath:destinationPath handler:nil])
        return NO;
        
    // Update the Dock's trash icon, if possible.
    notifyThatTrashChanged(trashPath);
    
    return YES;
}


// PathToFSRef and FSRefToPathCopy are borrowed from BDAlias

static OSErr PathToFSRef(CFStringRef inPath, FSRef *outRef)
{
    CFURLRef	tempURL = NULL;
    Boolean	gotRef = false;

    tempURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, inPath,
                                            kCFURLPOSIXPathStyle, false);

    if (tempURL == NULL) {
        return fnfErr;
    }

    gotRef = CFURLGetFSRef(tempURL, outRef);

    CFRelease(tempURL);

    if (gotRef == false) {
        return fnfErr;
    }

    return noErr;
}

static CFStringRef FSRefToPathCopy(const FSRef *inRef)
{
    CFURLRef	tempURL = NULL;
    CFStringRef	result = NULL;

    if (inRef != NULL) {
        tempURL = CFURLCreateFromFSRef(kCFAllocatorDefault, inRef);

        if (tempURL == NULL) {
            return NULL;
        }

        result = CFURLCopyFileSystemPath(tempURL, kCFURLPOSIXPathStyle);

        CFRelease(tempURL);
    }

    return result;
}

static NSString *trashPathForFile(NSString *filePath)
{
    OSErr err;
    FSRef fileRef;
    FSCatalogInfo catalogInfo;
    FSRef trashRef;
    NSString *trashPath;

    // Find the volume the file is on.
    err = PathToFSRef((CFStringRef)filePath, &fileRef);
    if (err != noErr) {
#if DEBUG
        NSLog(@"trashPathForFile(%@): PathToFSRef failed: %hd", filePath, err);
#endif
        return nil;
    }

    err = FSGetCatalogInfo(&fileRef, kFSCatInfoVolume, &catalogInfo, NULL, NULL, NULL);
    if (err != noErr) {
#if DEBUG
        NSLog(@"trashPathForFile(%@): FSGetCatalogInfo failed: %hd", filePath, err);
#endif
        return nil;
    }

    // Find the trash for that volume.
    err = FSFindFolder(catalogInfo.volume, kTrashFolderType, kCreateFolder, &trashRef);
    if (err != noErr) {
#if DEBUG
        NSLog(@"trashPathForFile(%@): FSFindFolder failed: %hd", filePath, err);
#endif
        return nil;
    }

    // Translate the trash's FSRef back to a path so we can use it.
    trashPath = [(NSString *)FSRefToPathCopy(&trashRef) autorelease];
    if (!trashPath) {
#if DEBUG
        NSLog(@"trashPathForFile(%@): FSRefToPathCopy failed!", filePath);
#endif
        return nil;
    }

    return trashPath;
}

static NSString *destinationNameForFileInTrash(NSString *fileName, NSString *trashPath)
{
    NSFileManager *fileManager;
    NSString *destinationName;
    NSString *fileNameWithoutExtension;
    NSString *fileNameExtension;
    unsigned int suffix = 0;

    fileManager = [NSFileManager defaultManager];

    // Check the common case first
    if (![fileManager fileExistsAtPath:[trashPath stringByAppendingPathComponent:fileName]])
        return fileName;

    fileNameWithoutExtension = [fileName stringByDeletingPathExtension];
    fileNameExtension = [fileName pathExtension];

    do {
        NSString *suffixString;

        suffix++;
        if (suffix == 1)
            suffixString = @" copy";
        else
            suffixString = [NSString stringWithFormat:@" copy %u", suffix];
        // TODO The word "copy" should be localized

        destinationName = [[fileNameWithoutExtension stringByAppendingString:suffixString] stringByAppendingPathExtension:fileNameExtension];
    } while ([fileManager fileExistsAtPath:[trashPath stringByAppendingPathComponent:destinationName]]);

    return destinationName;
}

static void notifyThatTrashChanged(NSString *trashPath)
{
    OSStatus status;

    // TODO This doesn't work in Mac OS X 10.1.3.  The Trash icon in the Dock, and the Finder's view of the Trash,
    // does not update consistently. Sometimes the Dock icon will update when it is clicked on, sometimes not.
    // Sometimes the files appear in the Finder's Trash window, sometimes not.

    status = FNNotifyByPath([trashPath fileSystemRepresentation], kFNDirectoryModifiedMessage, kNilOptions);
    if (status != noErr) {
#if DEBUG
        NSLog(@"FNNotifyByPath(%@) failed: %ld", trashPath, status);
#endif
    }
}

#endif

@end
