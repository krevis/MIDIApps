#include <Carbon/Carbon.h>
#include "MoreFilesXSubset.h"


/*****************************************************************************/

#pragma mark ----- Local type definitions -----

struct FSDeleteContainerGlobals
{
    OSErr		result;			/* result */
    ItemCount		actualObjects;	/* number of objects returned */
    FSCatalogInfo	catalogInfo;		/* FSCatalogInfo */
};
typedef struct FSDeleteContainerGlobals FSDeleteContainerGlobals;

/*****************************************************************************/

/*
	The FSDeleteContainerLevel function deletes the contents of a container
	directory. All files and subdirectories in the specified container are
	deleted. If a locked file or directory is encountered, it is unlocked
	and then deleted. If any unexpected errors are encountered,
	FSDeleteContainerLevel quits and returns to the caller.

	container			--> FSRef to a directory.
	theGlobals			--> A pointer to a FSDeleteContainerGlobals struct
 which contains the variables that do not need to
 be allocated each time FSDeleteContainerLevel
 recurses. That lets FSDeleteContainerLevel use
 less stack space per recursion level.
 */

static
void
FSDeleteContainerLevel(
                       const FSRef *container,
                       FSDeleteContainerGlobals *theGlobals)
{
    /* level locals */
    FSIterator					iterator;
    FSRef						itemToDelete;
    UInt16						nodeFlags;

    /* Open FSIterator for flat access and give delete optimization hint */
    theGlobals->result = FSOpenIterator(container, kFSIterateFlat + kFSIterateDelete, &iterator);
    require_noerr(theGlobals->result, FSOpenIterator);

    /* delete the contents of the directory */
    do
    {
        /* get 1 item to delete */
        theGlobals->result = FSGetCatalogInfoBulk(iterator, 1, &theGlobals->actualObjects,
                                                  NULL, kFSCatInfoNodeFlags, &theGlobals->catalogInfo,
                                                  &itemToDelete, NULL, NULL);
        if ( (noErr == theGlobals->result) && (1 == theGlobals->actualObjects) )
        {
            /* save node flags in local in case we have to recurse */
            nodeFlags = theGlobals->catalogInfo.nodeFlags;

            /* is it a file or directory? */
            if ( 0 != (nodeFlags & kFSNodeIsDirectoryMask) )
            {
                /* it's a directory -- delete its contents before attempting to delete it */
                FSDeleteContainerLevel(&itemToDelete, theGlobals);
            }
            /* are we still OK to delete? */
            if ( noErr == theGlobals->result )
            {
                /* is item locked? */
                if ( 0 != (nodeFlags & kFSNodeLockedMask) )
                {
                    /* then attempt to unlock it (ignore result since FSDeleteObject will set it correctly) */
                    theGlobals->catalogInfo.nodeFlags = nodeFlags & ~kFSNodeLockedMask;
                    (void) FSSetCatalogInfo(&itemToDelete, kFSCatInfoNodeFlags, &theGlobals->catalogInfo);
                }
                /* delete the item */
                theGlobals->result = FSDeleteObject(&itemToDelete);
            }
        }
    } while ( noErr == theGlobals->result );

    /* we found the end of the items normally, so return noErr */
    if ( errFSNoMoreItems == theGlobals->result )
    {
        theGlobals->result = noErr;
    }

    /* close the FSIterator (closing an open iterator should never fail) */
    verify_noerr(FSCloseIterator(iterator));

FSOpenIterator:

        return;
}

/*****************************************************************************/

OSErr
FSDeleteContainerContents(
                          const FSRef *container)
{
    FSDeleteContainerGlobals	theGlobals;

    /* delete container's contents */
    FSDeleteContainerLevel(container, &theGlobals);

    return ( theGlobals.result );
}
