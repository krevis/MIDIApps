/*
	File:		FSCopyObject.h
	
	Contains:	A Copy/Delete Files/Folders engine which uses the HFS+ API's

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

#ifndef __FSCOPYOBJECT_H__
#define __FSCOPYOBJECT_H__

#ifdef __cplusplus
extern "C" {
#endif

#if TARGET_API_MAC_OSX || defined( __APPLE_CC__ )
#include	<CoreServices/CoreServices.h>
#endif

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


#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4
        // On 10.4 and later, use official Carbon FSCopyObjectsSync() or similar.

/*
	This code takes some tricks/techniques from MoreFilesX (by Jim Luther) and
	MPFileCopy (by Quinn), wraps them all up into an easy to use API, and adds a bunch of
	features and bug fixes.  It will run on Mac OS 9.1 through 9.2.x and 10.1.x
	and up (Classic, Carbon and Mach-O)
*/

	/* Different options that FSCopyObject can take during a copy */
typedef	UInt32				DupeAction;
enum {
	kDupeActionStandard,	/* will do the copy with no frills */
	kDupeActionReplace,		/* will delete the existing object and then copy over the new one */
	kDupeActionRename		/* will rename the new object if an object of the same name exists */
};

/*****************************************************************************/

#pragma mark CopyObjectFilterProcPtr

/*
	This is the prototype for the CallCopyObjectFilterProc function which
	is called once for each file and directory found by FSCopyObject.
	The CallCopyObjectFilterProc can use the read-only data it receives for
	whatever it wants.

	The result of the CallCopyObjectFilterProc function indicates if
	the copy should be stopped.  To stop the copy, return an error; to continue
	the copy, return noErr.

	The yourDataPtr parameter can point to whatever data structure you might
	want to access from within the CallCopyObjectFilterProc.
	
	Note: If an error had occured during the copy of the current object
	(currentOSErr != noErr) the FSRef etc might not be valid

	containerChanged	--> Set to true if the container's contents changed
							during iteration.
	currentLevel		--> The current recursion level into the container.
							1 = the container, 2 = the container's immediate
							subdirectories, etc.
	currentOSErr		--> The current error code, shows the results of the
							copy of the current object (ref)
	catalogInfo			--> The catalog information for the current object.
							Only the fields requested by the whichInfo
							parameter passed to FSIterateContainer are valid.
	ref					--> The FSRef to the current object.
	spec				--> The FSSpec to the current object if the wantFSSpec
							parameter passed to FSCopyObject is true.
	name				--> The name of the current object if the wantName
							parameter passed to FSCopyObject is true.
	yourDataPtr			--> An optional pointer to whatever data structure you
							might want to access from within the
							CallCopyObjectFilterProc.
	result				<-- To continue the copy, return noErr
	
	__________

	Also see:	FSCopyObject
*/

typedef CALLBACK_API( OSErr , CopyObjectFilterProcPtr ) (
	Boolean containerChanged,
	ItemCount currentLevel,
	OSErr currentOSErr,
	const FSCatalogInfo *catalogInfo,
	const FSRef *ref,
	const FSSpec *spec,
	const HFSUniStr255 *name,
	void *yourDataPtr);


/*****************************************************************************/

#pragma mark CallCopyObjectFilterProc

#define CallCopyObjectFilterProc(userRoutine, containerChanged, currentLevel, currentOSErr, catalogInfo, ref, spec, name, yourDataPtr) \
	(*(userRoutine))((containerChanged), (currentLevel), (currentOSErr), (catalogInfo), (ref), (spec), (name), (yourDataPtr))

/*****************************************************************************/

#pragma mark FSCopyObject

/*
	The FSCopyObject function takes a source object (can be a file or directory)
	and copies it (and its contents if it's a directory) to the new destination
	directory.
	
	It will call your CopyObjectFilterProcPtr once for each object copied

	The maxLevels parameter is only used when the object is a directory,
	ignored otherwise.
	It lets you control how deep the recursion goes.
	If maxLevels is 1, FSCopyObject only scans the specified directory;
	if maxLevels is 2, FSCopyObject scans the specified directory and
	one subdirectory below the specified directory; etc. Set maxLevels to
	zero to scan all levels.

	The yourDataPtr parameter can point to whatever data structure you might
	want to access from within your CopyObjectFilterProcPtr.

	source				--> The FSRef to the object you want to copy
	destDir				--> The FSRef to the directory you wish to copy source to
	maxLevels			--> Maximum number of directory levels to scan or
							zero to scan all directory levels, ignored if the
							object is a file
	whichInfo			--> The fields of the FSCatalogInfo you wish passed
							to you in your CopyObjectFilterProc
	dupeAction			--> The action to take if an object of the same name exists
							in the destination
	newName				--> The name you want the new object to have.  If you pass
							in NULL, the source object name will be used. 
	wantFSSpec			--> Set to true if you want the FSSpec to each
							object passed to your CopyObjectFilterProc.
	wantName			--> Set to true if you want the name of each
							object passed to your CopyObjectFilterProc.
	filterProcPtr		--> A pointer to the CopyObjectFilterProc you
							want called once for each object found
							by FSCopyObject.
	yourDataPtr			--> An optional pointer to whatever data structure you
							might want to access from within the
							CopyObjectFilterProc.
	newObjectRef		--> An optional pointer to an FSRef that, on return,
							references the new object.  If you don't want this
							info returned, pass in NULL
	newObjectSpec		--> An optional pointer to an FSSPec that, on return,
							references the new object.  If you don't want this
							info returned, pass in NULL
*/

OSErr FSCopyObject(	const FSRef *source,
					const FSRef *destDir,
				 	ItemCount maxLevels,
				 	FSCatalogInfoBitmap whichInfo,
				 	DupeAction dupeAction,
				 	const HFSUniStr255 *newName,			/* can be NULL */
					Boolean wantFSSpec,
					Boolean wantName,
					CopyObjectFilterProcPtr filterProcPtr,	/* can be NULL */
					void *yourDataPtr,						/* can be NULL */
					FSRef *newObjectRef,					/* can be NULL */
					FSSpec *newObjectSpec);					/* can be NULL */

#endif  // MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4

    
/*****************************************************************************/

#pragma mark FSDeleteObjects

/*
	The FSDeleteObjects function takes an FSRef to a file or directory
	and attempts to delete it.  If the object is a directory, all files
	and subdirectories in the specified directory are deleted. If a
	locked file or directory is encountered, it is unlocked and then
	deleted.  After deleting the directory's contents, the directory
	is deleted. If any unexpected errors are encountered, 
	FSDeleteContainer quits and returns to the caller.
	
	source				--> FSRef to an object (can be file or directory).
	
	__________
*/

OSErr FSDeleteObjects( const FSRef *source );

    
#ifdef __cplusplus
}
#endif

#endif
