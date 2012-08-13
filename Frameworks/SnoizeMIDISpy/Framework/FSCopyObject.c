/*
	File:		FSCopyObject.c
	
	Contains:	A Copy/Delete Files/Folders engine which uses HFS+ API's.
				This code takes some tricks/techniques from MoreFilesX and
				MPFileCopy, wraps them all up into an easy to use API, and
				adds a bunch of features.  It will run on Mac OS 9.1 through 
				9.2.x and 10.1.x and up (Classic, Carbon and Mach-O)

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
				("Apple") in consideration of your agreement to the following terms, and your
				use, installation, modification or redistribution of this Apple software
				constitutes acceptance of these terms.  If you do not agree with these terms,
				please do not use, install, modify or redistribute this Apple software.

				In consideration of your agreement to abide by the following terms, and subject
				to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
				copyrights in this original Apple software (the "Apple Software"), to use,
				reproduce, modify and redistribute the Apple Software, with or without
				modifications, in source and/or binary forms; provided that if you redistribute
				the Apple Software in its entirety and without modifications, you must retain
				this notice and the following text and disclaimers in all such redistributions of
				the Apple Software.  Neither the name, trademarks, service marks or logos of
				Apple Computer, Inc. may be used to endorse or promote products derived from the
				Apple Software without specific prior written permission from Apple.  Except as
				expressly stated in this notice, no other rights or licenses, express or implied,
				are granted by Apple herein, including but not limited to any patent rights that
				may be infringed by your derivative works or by other works in which the Apple
				Software may be incorporated.

				The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
				WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
				WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
				PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
				COMBINATION WITH YOUR PRODUCTS.

				IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
				CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
				GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
				ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
				OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
				(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
				ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

	Copyright © 2002-2004 Apple Computer, Inc., All Rights Reserved
*/

#include "FSCopyObject.h"

//#define DEBUG  1	/* set to zero if you don't want debug spew */

#if DEBUG
#include <stdio.h>

#define QuoteExceptionString(x) #x

#define dwarning(s)					do { printf s; fflush(stderr); } while( 0 )

#define mycheck_noerr( error )												\
do {																	\
if( (OSErr) error != noErr ) {										\
dwarning((QuoteExceptionString(error) " != noErr in File: %s, Function: %s, Line: %d, Error: %d\n",	\
__FILE__, __FUNCTION__, __LINE__, (OSErr) error));		\
}																	\
} while( false )

#define mycheck( assertion )												\
do {																	\
if( ! assertion ) {													\
dwarning((QuoteExceptionString(assertion) " failed in File: %s, Function: %s, Line: %d\n",	\
__FILE__, __FUNCTION__, __LINE__));	\
}																	\
} while( false )

#define myverify(assertion)			mycheck(assertion)
#define myverify_noerr(assertion)	mycheck_noerr( (assertion) )
#else
#define	dwarning(s)

#define mycheck(assertion)
#define mycheck_noerr(err)
#define myverify(assertion)			do { (void) (assertion); } while (0)
#define myverify_noerr(assertion) 	myverify(assertion)
#endif



	/* The FSDeleteObjectGlobals data structure holds information needed to */
	/* recursively delete a directory										*/
struct FSDeleteObjectGlobals
{
	FSCatalogInfo			catalogInfo;		/* FSCatalogInfo				*/
	ItemCount				actualObjects;		/* number of objects returned	*/
	OSErr					result;				/* result						*/
};
typedef struct FSDeleteObjectGlobals FSDeleteObjectGlobals;



static OSErr	FSDeleteFolder		  (	const FSRef			*container );

static void		FSDeleteFolderLevel	  (	const FSRef			*container,
										FSDeleteObjectGlobals *theGlobals );


/*****************************************************************************/

#pragma mark ----- Delete Objects -----

OSErr FSDeleteObjects( const FSRef *source )
{
	FSCatalogInfo	catalogInfo;
	OSErr			err = ( source != NULL ) ? noErr : paramErr;
	
#if DEBUG && !TARGET_API_MAC_OS8
	if( err == noErr )
	{
		char	path[1024];
		myverify_noerr(FSRefMakePath( source,	(unsigned char*)path, 1024 ));
		dwarning(("\n%s -- Deleting %s\n", __FUNCTION__, path));
	}
#endif
    
    /* get nodeFlags for container */
	if( err == noErr )
		err = FSGetCatalogInfo(source, kFSCatInfoNodeFlags, &catalogInfo, NULL, NULL,NULL);
	if( err == noErr && (catalogInfo.nodeFlags & kFSNodeIsDirectoryMask) != 0 )
	{		/* its a directory, so delete its contents before we delete it */
		err = FSDeleteFolder(source);
	}
	if( err == noErr && (catalogInfo.nodeFlags & kFSNodeLockedMask) != 0 )	/* is object locked? */
	{		/* then attempt to unlock the object (ignore err since FSDeleteObject will set it correctly) */
		catalogInfo.nodeFlags &= ~kFSNodeLockedMask;
		(void) FSSetCatalogInfo(source, kFSCatInfoNodeFlags, &catalogInfo);
	}
	if( err == noErr )	/* delete the object (if it was a directory it is now empty, so we can delete it) */
		err = FSDeleteObject(source);
    
	mycheck_noerr( err );
	
	return ( err );
}

/*****************************************************************************/

#pragma mark ----- Delete Folders -----

static OSErr FSDeleteFolder( const FSRef *container )
{
	FSDeleteObjectGlobals theGlobals;
	
	theGlobals.result = ( container != NULL ) ? noErr : paramErr;
	
    /* delete container's contents */
	if( theGlobals.result == noErr )
		FSDeleteFolderLevel(container, &theGlobals);
	
	mycheck_noerr( theGlobals.result );
	
	return ( theGlobals.result );
}

/*****************************************************************************/

static void FSDeleteFolderLevel(const FSRef				*container,
								FSDeleteObjectGlobals	*theGlobals )
{
	FSIterator					iterator;
	FSRef						itemToDelete;
	UInt16						nodeFlags;
    
    /* Open FSIterator for flat access and give delete optimization hint */
	theGlobals->result = FSOpenIterator(container, kFSIterateFlat + kFSIterateDelete, &iterator);
	if ( theGlobals->result == noErr )
	{
		do 	/* delete the contents of the directory */
		{
            /* get 1 item to delete */
			theGlobals->result = FSGetCatalogInfoBulk(	iterator, 1, &theGlobals->actualObjects,
                                                      NULL, kFSCatInfoNodeFlags, &theGlobals->catalogInfo,
                                                      &itemToDelete, NULL, NULL);
			if ( (theGlobals->result == noErr) && (theGlobals->actualObjects == 1) )
			{
                /* save node flags in local in case we have to recurse */
				nodeFlags = theGlobals->catalogInfo.nodeFlags;
				
                /* is it a directory? */
				if ( (nodeFlags & kFSNodeIsDirectoryMask) != 0 )
				{	/* yes -- delete its contents before attempting to delete it */
					FSDeleteFolderLevel(&itemToDelete, theGlobals);
				}
				if ( theGlobals->result == noErr)			/* are we still OK to delete? */
				{
					if ( (nodeFlags & kFSNodeLockedMask) != 0 )	/* is item locked? */
					{		/* then attempt to unlock it (ignore result since FSDeleteObject will set it correctly) */
						theGlobals->catalogInfo.nodeFlags = nodeFlags & ~kFSNodeLockedMask;
						(void) FSSetCatalogInfo(&itemToDelete, kFSCatInfoNodeFlags, &theGlobals->catalogInfo);
					}
                    /* delete the item */
					theGlobals->result = FSDeleteObject(&itemToDelete);
				}
			}
		} while ( theGlobals->result == noErr );
        
        /* we found the end of the items normally, so return noErr */
		if ( theGlobals->result == errFSNoMoreItems )
			theGlobals->result = noErr;
        
        /* close the FSIterator (closing an open iterator should never fail) */
		myverify_noerr(FSCloseIterator(iterator));
	}
    
	mycheck_noerr( theGlobals->result );
	
	return;
}

