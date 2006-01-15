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
#include "GenLinkedList.h"
#if !TARGET_API_MAC_OSX
#include <UnicodeConverter.h>
#endif
#include <stddef.h>
#include <string.h>

#pragma mark ----- Tunable Parameters -----

/* The following constants control the behavior of the copy engine. */

enum {		/* BufferSizeForVolSpeed */
/*	kDefaultCopyBufferSize	=   2L * 1024 * 1024,*/ 		/* 2MB,   Fast but not very responsive. */
	kDefaultCopyBufferSize	= 256L * 1024,					/* 256kB, Slower but can still use machine. */
	kMaximumCopyBufferSize	=   2L * 1024 * 1024,
	kMinimumCopyBufferSize	= 1024
};

enum {		/* CheckForDestInsideSrc */
	errFSDestInsideSource	= -1234
};

enum {		
			/* for use with PBHGetDirAccess in IsDropBox */
	kPrivilegesMask			= kioACAccessUserWriteMask | kioACAccessUserReadMask | kioACAccessUserSearchMask,

			/* for use with FSGetCatalogInfo and FSPermissionInfo->mode			*/
			/* from sys/stat.h...  note -- sys/stat.h definitions are in octal	*/
			/*																	*/
			/* You can use these values to adjust the users/groups permissions	*/
			/* on a file/folder with FSSetCatalogInfo and extracting the		*/
			/* kFSCatInfoPermissions field.  See code below for examples		*/
	kRWXUserAccessMask		= 0x01C0,
	kReadAccessUser			= 0x0100,
	kWriteAccessUser		= 0x0080,
	kExecuteAccessUser		= 0x0040,

	kRWXGroupAccessMask		= 0x0038,
	kReadAccessGroup		= 0x0020,
	kWriteAccessGroup		= 0x0010,
	kExecuteAccessGroup		= 0x0008,

	kRWXOtherAccessMask		= 0x0007,
	kReadAccessOther		= 0x0004,
	kWriteAccessOther		= 0x0002,
	kExecuteAccessOther		= 0x0001,

	kDropFolderValue		= kWriteAccessOther | kExecuteAccessOther
};

#define	kNumObjects			80

#define VolHasCopyFile(volParms)	(((volParms)->vMAttrib & (1L << bHasCopyFile)) != 0)

#pragma mark ----- Struct Definitions -----

	/* The CopyParams data structure holds the copy buffer used	*/
	/* when copying the forks over, as well as special case		*/
	/* info on the destination									*/
struct CopyParams {
	void 				   *copyBuffer;
	ByteCount 				copyBufferSize;
	Boolean         		copyingToDropFolder;
	Boolean					copyingToLocalVolume;
	Boolean					volHasCopyFile;
	DupeAction				dupeAction;
};
typedef struct CopyParams CopyParams;

	/* The FilterParams data structure holds the date and info		*/
	/* that the caller wants passed into the Filter Proc, as well	*/
	/* as the Filter Proc Pointer itself							*/
struct FilterParams {
	FSCatalogInfoBitmap		whichInfo;
	CopyObjectFilterProcPtr	filterProcPtr;
	Boolean					containerChanged;
	Boolean					wantSpec;
	Boolean					wantName;
	void				   *yourDataPtr;
};
typedef struct FilterParams FilterParams;

	/* The ForkTracker data structure holds information about a specific fork,	*/
	/* specifically the name and the refnum.  We use this to build a list of	*/
	/* all the forks before we start copying them.  We need to do this because	*/
	/* if we're copying into a drop folder, we must open all the forks before	*/
	/* we start copying data into any of them.									*/
	/* Plus it's a convenient way to keep track of all the forks...				*/
struct ForkTracker {
	HFSUniStr255 			forkName;
	SInt64					forkSize;
	SInt16       			forkDestRefNum;
};
typedef struct ForkTracker ForkTracker;
typedef ForkTracker *ForkTrackerPtr;

	/* The FolderListData data structure holds FSRefs to the source and			*/
	/* coorisponding destination folder, as well as which level its on			*/
	/* for use in ProcessFolderList.											*/ 
struct FolderListData
{
	FSRef					sourceDirRef;
	FSRef					destDirRef;
	UInt32					level;
};
typedef struct FolderListData FolderListData;

	/* The FSCopyFolderGlobals data structure holds the information needed to	*/
	/* copy a directory															*/
struct FSCopyFolderGlobals
{
	FSRef				   *sourceDirRef;
	FSRef				   *destDirRef;

	FSCatalogInfo		   *catInfoList;
	FSRef				   *srcRefList;
	HFSUniStr255		   *nameList;
	
	GenLinkedList			folderList;
	GenIteratorPtr			folderListIter;
	
	CopyParams			   *copyParams;
	FilterParams		   *filterParams;
	Boolean					containerChanged;
	
	ItemCount				maxLevels;
	ItemCount				currentLevel;
};
typedef struct FSCopyFolderGlobals FSCopyFolderGlobals;

	/* The FSDeleteObjectGlobals data structure holds information needed to */
	/* recursively delete a directory										*/
struct FSDeleteObjectGlobals
{
	FSCatalogInfo			catalogInfo;		/* FSCatalogInfo				*/
	ItemCount				actualObjects;		/* number of objects returned	*/
	OSErr					result;				/* result						*/
};
typedef struct FSDeleteObjectGlobals FSDeleteObjectGlobals;

#pragma mark ----- Local Prototypes -----

static OSErr	FSCopyObjectPreflight (	const FSRef			*source,
										const FSRef			*destDir,
										const DupeAction	 dupeAction,
										FSCatalogInfo		*sourceCatInfo,
										CopyParams			*copyParams,		/* can be NULL */
										HFSUniStr255		*newObjectName,
										FSRef				*deleteMeRef,
										Boolean				*isReplacing,
										Boolean				*isDirectory );

static OSErr	FSCopyFile			  (	const FSRef			*source,
									 	const FSRef			*destDir,
									 	const FSCatalogInfo	*sourceCatInfo,
								 		const HFSUniStr255	*newFileName,
									 	CopyParams			*copyParams,
								 		FilterParams		*filterParams,
						 				FSRef				*newFileRef,		/* can be NULL */
						 				FSSpec				*newFileSpec );		/* can be NULL */
							 	
static OSErr	CopyFile			  (	const FSRef			*source,
										FSCatalogInfo		*sourceCatInfo,
									 	const FSRef			*destDir,
									 	const HFSUniStr255 	*destName,			/* can be NULL */
										CopyParams			*copyParams,
										FSRef 				*newRef,			/* can be NULL */
										FSSpec				*newSpec );			/* can be NULL */
								
static	OSErr 	FSUsePBHCopyFile	  (	const FSRef			*srcFileRef,
										const FSRef 		*dstDirectoryRef,
										const HFSUniStr255 	*destName,			/* can be NULL (no rename during copy) */
										TextEncoding 		textEncodingHint,
										FSRef 				*newRef,			/* can be NULL */
										FSSpec				*newSpec );			/* can be NULL */
											
static OSErr	DoCopyFile			  (	const FSRef 		*source,
										FSCatalogInfo		*sourceCatInfo,
										const FSRef			*destDir,
										const HFSUniStr255 	*destName,
										CopyParams			*params, 
										FSRef				*newRef,			/* can be NULL */
										FSSpec				*newSpec );			/* can be NULL */

static OSErr	FSCopyFolder  		  (	const FSRef			*source,
										const FSRef			*destDir,
									 	const FSCatalogInfo	*sourceCatInfo,
										const HFSUniStr255	*newFoldName,
										CopyParams			*copyParams,
										FilterParams		*filterParams,
										ItemCount			 maxLevels,
										FSRef				*outDirRef,			/* can be NULL */
										FSSpec				*outDirSpec );		/* can be NULL */

static OSErr	ProcessFolderList	  (	FSCopyFolderGlobals *folderGlobals );

static OSErr	CopyFolder			  (	FSCopyFolderGlobals	*folderGlobals );

static OSErr	CheckForDestInsideSrc (	const FSRef			*source,
										const FSRef			*destDir );

static OSErr	CopyForks			  (	const FSRef			*source,
										const FSRef			*dest,
										CopyParams			*params );

static OSErr	CopyForksToDisk		  (	const FSRef			*source,
										const FSRef			*dest,
										CopyParams			*params );
										
static OSErr	CopyForksToDropBox	  (	const FSRef			*source,
										const FSRef			*dest,
										CopyParams			*params );

static OSErr	OpenAllForks		  (	const FSRef			*dest,
										GenLinkedList		*forkList );

static OSErr	WriteFork			  (	const SInt16		srcRefNum,
										const SInt16		destRefNum,
										const CopyParams	*params,
										const SInt64		forkSize );

static UInt32	CalcBufferSizeForVol  (	const GetVolParmsInfoBuffer *volParms,
										UInt32				volParmsSize );

static UInt32	BufferSizeForVolSpeed (	UInt32				volumeBytesPerSecond );

static OSErr	FSDeleteFolder		  (	const FSRef			*container );

static void		FSDeleteFolderLevel	  (	const FSRef			*container,
										FSDeleteObjectGlobals *theGlobals );

static OSErr	IsDropBox			  (	const FSRef			*source,
										Boolean				*isDropBox );

static OSErr	GetMagicBusyCreateDate(	UTCDateTime			*date );

static OSErr	FSGetVRefNum		  (	const FSRef			*ref,
										FSVolumeRefNum		*vRefNum );

static OSErr	FSGetVolParms		  (	FSVolumeRefNum		  volRefNum,
										UInt32				  bufferSize,
										GetVolParmsInfoBuffer*volParmsInfo,
										UInt32				 *actualInfoSize );	/*	Can Be NULL	*/

static OSErr	UniStrToPStr		  (	const HFSUniStr255	*uniStr,
										TextEncoding		 textEncodingHint,
										Boolean				 isVolumeName,
										Str255				 pStr );

static OSErr	FSMakeFSRef			  (	FSVolumeRefNum		 volRefNum,
										SInt32				 dirID,
										ConstStr255Param	 name,
										FSRef				*ref );
						
static OSErr	SetupDestination	  (	const FSRef			*destDir,
										const DupeAction	 dupeAction,
										HFSUniStr255		*sourceName,
										FSRef				*deleteMeRef,
										Boolean				*isReplacing);

static OSErr	GetUniqueName		  (	const FSRef			*destDir,
										HFSUniStr255		*sourceName );

static OSErr	GetObjectName		  (	const FSRef			*sourceRef,
										HFSUniStr255		*sourceName,
										TextEncoding		*sourceEncoding );
									
static OSErr	CreateFolder		  (	const FSRef			*sourceRef,
							  			const FSRef			*destDirRef,
							  			const FSCatalogInfo	*catalogInfo,
							  			const HFSUniStr255	*folderName,
							  			CopyParams			*params,
							  			FSRef				*newFSRefPtr,
							  			FSSpec				*newFSSpecPtr );

static OSErr	DoCreateFolder		  (	const FSRef			*sourceRef,
										const FSRef			*destDirRef,
										const FSCatalogInfo	*catalogInfo,
										const HFSUniStr255	*folderName,
										CopyParams			*params,
										FSRef			 	*newFSRefPtr,
										FSSpec				*newFSSpecPtr);

static pascal void MyDisposeDataProc  (	void				*pData );

static pascal void MyCloseForkProc	  (	void				*pData );

/*****************************************************************************/
/*****************************************************************************/
/*****************************************************************************/

#pragma mark ----- Copy Objects -----

	/* This routine acts as the top level of the copy engine.	*/ 
OSErr FSCopyObject(	const FSRef				*source,
					const FSRef				*destDir,
				 	ItemCount				maxLevels,
				 	FSCatalogInfoBitmap		whichInfo,
				 	DupeAction				dupeAction,
				 	const HFSUniStr255		*newObjectName,	/* can be NULL */
					Boolean					wantFSSpec,
					Boolean					wantName,
					CopyObjectFilterProcPtr filterProcPtr,	/* can be NULL */
					void					*yourDataPtr,	/* can be NULL */
					FSRef					*newObjectRef,	/* can be NULL */
					FSSpec					*newObjectSpec)	/* can be NULL */
{
	CopyParams   	copyParams;
	FilterParams	filterParams;
	FSCatalogInfo	sourceCatInfo;
	HFSUniStr255	sourceName,
					tmpObjectName;
	FSRef			tmpObjectRef,
					deleteMeRef;
	Boolean			isDirectory = false,
					isReplacing = false;
	OSErr			err = ( source != NULL && destDir != NULL ) ? noErr : paramErr;

		/* Zero out these two FSRefs in case an error occurs before or	*/
		/* inside FSCopyObjectPreflight.  Paranoia mainly...			*/
	BlockZero( &deleteMeRef,	sizeof( FSRef ) );
	BlockZero( &tmpObjectRef,	sizeof( FSRef ) );

		/* setup filterParams */
	filterParams.whichInfo		= whichInfo;
	filterParams.filterProcPtr	= filterProcPtr;
	filterParams.wantSpec		= ( filterProcPtr && wantFSSpec );	/* only get this info if	*/
	filterParams.wantName		= ( filterProcPtr && wantName );	/* a filterProc is provied	*/
	filterParams.yourDataPtr	= yourDataPtr;
	
		/* Get and store away the name of the source object */
		/* and setup the initial name of the new object		*/
	if( err == noErr )
		err = GetObjectName( source, &sourceName, NULL );
	if( err == noErr )
		tmpObjectName = (newObjectName != NULL) ? *newObjectName : sourceName;

	if( err == noErr )		/* preflight/prep the destination and our internal variables */
		err = FSCopyObjectPreflight( source, destDir, dupeAction, &sourceCatInfo, &copyParams, &tmpObjectName, &deleteMeRef, &isReplacing, &isDirectory );
		
							/* now that we have some info, lets print it */
	if( err == noErr )
	{
		dwarning(( "%s -- err: %d, maxLevels: %u, whichInfo: %08x,\n", __FUNCTION__, err, (unsigned int)maxLevels, (int)whichInfo ));
		dwarning(( "\t\t\t\tdupeAction: %s, wantSpec: %s, wantName: %s,\n", ((dupeAction == kDupeActionReplace) ? "replace" : ((dupeAction == kDupeActionRename) ? "rename" : "standard")), (filterParams.wantSpec)?"yes":"no", (filterParams.wantName)?"yes":"no" ));
		dwarning(( "\t\t\t\tfilterProcPtr: 0x%08x, yourDataPtr: 0x%08x,\n", (unsigned int)filterProcPtr, (unsigned int)yourDataPtr ));
		dwarning(( "\t\t\t\tnewObjectRef: 0x%08x, newObjectSpec: 0x%08x,\n", (unsigned int)newObjectRef, (unsigned int)newObjectSpec ));
		dwarning(( "\t\t\t\tcopyBufferSize: %dkB, isDirectory: %s, isLocal: %s,\n", (int)copyParams.copyBufferSize/1024, (isDirectory)?"yes":"no", (copyParams.copyingToLocalVolume)?"yes":"no" ));
		dwarning(( "\t\t\t\tisDropBox: %s, PBHCopyFileSync supported: %s\n\n", (copyParams.copyingToDropFolder)?"yes":"no", (copyParams.volHasCopyFile)?"yes":"no" ));
	}
		
	if( err == noErr )		/* now copy the file/folder... */
	{		/* is it a folder? */
		if ( isDirectory )
		{		/* yes */
			err = CheckForDestInsideSrc(source, destDir);			
			if( err == noErr )
				err = FSCopyFolder( source, destDir, &sourceCatInfo, &tmpObjectName, &copyParams, &filterParams, maxLevels, &tmpObjectRef, newObjectSpec );
		}
		else	/* no */
			err = FSCopyFile(source, destDir, &sourceCatInfo, &tmpObjectName, &copyParams, &filterParams, &tmpObjectRef, newObjectSpec);
	}
	
		/* if an object existed in the destination with the same name as	*/
		/* the source and the caller wants to replace it, we had renamed it	*/
		/* to ".DeleteMe" earlier.  If no errors, we delete it, else delete	*/
		/* the one we just created and rename the origenal back to its		*/
		/* origenal name.													*/
		/*																	*/
		/* This is done mainly to cover the case of the	source being in the	*/
		/* destination directory when kDupeActionReplace is selected		*/
		/* (3188701)														*/
	if( copyParams.dupeAction == kDupeActionReplace && isReplacing == true )
	{
		dwarning(("%s -- Cleaning up, this might take a moment.  err : %d\n", __FUNCTION__, err));
	
		if( err == noErr )
			err = FSDeleteObjects( &deleteMeRef );
		else	
		{		/* not much we can do if the delete or rename fails, we need to preserve	*/
				/* the origenal error code that got us here.								*/
				/*																			*/
				/* If an error occurs before or inside SetupDestination, newFileRef and		*/
				/* deleteMeRef will be invalid so the delete and rename will simply fail	*/
				/* leaving the source and destination unchanged								*/
			myverify_noerr( FSDeleteObjects( &tmpObjectRef ) );
			myverify_noerr( FSRenameUnicode( &deleteMeRef, sourceName.length, sourceName.unicode, sourceCatInfo.textEncodingHint, NULL ) );
		}
	}
	
	if( err == noErr && newObjectRef != NULL )
		*newObjectRef = tmpObjectRef;

		/* Clean up for space and safety...  Who me? */
	if( copyParams.copyBuffer != NULL )
		DisposePtr((char*)copyParams.copyBuffer);
		
	mycheck_noerr( err );	
	
	return err;
}				 

/*****************************************************************************/

	/* Does a little preflighting (as the name suggests) to figure out the optimal	*/
	/* buffer size, if its a drop box, on a remote volume etc						*/
static OSErr FSCopyObjectPreflight(	const FSRef			*source,
									const FSRef			*destDir,
									const DupeAction	dupeAction,
									FSCatalogInfo		*sourceCatInfo,
									CopyParams   		*copyParams,
									HFSUniStr255		*newObjectName,
									FSRef				*deleteMeRef,
									Boolean				*isReplacing,
									Boolean				*isDirectory)
{
	GetVolParmsInfoBuffer	srcVolParms,
							destVolParms;
	UInt32					srcVolParmsSize = 0,
							destVolParmsSize = 0;
	FSVolumeRefNum			srcVRefNum,
							destVRefNum;
	OSErr					err = ( source		  != NULL && destDir	 != NULL &&
									sourceCatInfo != NULL && copyParams	 != NULL &&
									newObjectName != NULL && deleteMeRef != NULL &&
									isDirectory	  != NULL ) ? noErr : paramErr;

	BlockZero( copyParams, sizeof( CopyParams ) );

	copyParams->dupeAction = dupeAction;

	if( err == noErr )		/* Get the info we will need later about the source object	*/
		err = FSGetCatalogInfo( source, kFSCatInfoSettableInfo, sourceCatInfo, NULL, NULL, NULL );		
	if( err == noErr )		/* get the source's vRefNum									*/
		err = FSGetVRefNum( source, &srcVRefNum );
	if( err == noErr )		/* get the source's volParams								*/
		err = FSGetVolParms( srcVRefNum,  sizeof(GetVolParmsInfoBuffer), &srcVolParms, &srcVolParmsSize );			
	if( err == noErr )		/* get the destination's vRefNum							*/
		err = FSGetVRefNum( destDir, &destVRefNum );
	if( err == noErr )
	{
							/* Calculate the optimal copy buffer size for the src vol	*/
		copyParams->copyBufferSize = CalcBufferSizeForVol( &srcVolParms, srcVolParmsSize );
	
							/* if src and dest on different volumes, get its vol parms	*/
							/* and calculate its optimal buffer size					*/
							/* else destVolParms = srcVolParms							*/
		if( srcVRefNum != destVRefNum )
		{
			err = FSGetVolParms( destVRefNum, sizeof(GetVolParmsInfoBuffer), &destVolParms, &destVolParmsSize );
			if( err == noErr )
			{
				ByteCount tmpBufferSize = CalcBufferSizeForVol( &destVolParms, destVolParmsSize );
				if( tmpBufferSize < copyParams->copyBufferSize )
					copyParams->copyBufferSize = tmpBufferSize;				
			}
		}
		else 
			destVolParms = srcVolParms;
	}
	if( err == noErr )
		err = ((copyParams->copyBuffer = NewPtr( copyParams->copyBufferSize )) != NULL ) ? noErr : MemError();

		/* figure out if source is a file or folder			*/
		/*			  if it is on a local volume,			*/
		/*			  if destination is a drop box			*/
		/*			  if source and dest are on same server	*/
		/*			  and if it supports PBHCopyFile		*/
	if( err == noErr )		/* is the destination a Drop Box	*/
		err = IsDropBox( destDir, &copyParams->copyingToDropFolder );
	if( err == noErr )
	{
			/* Is it a directory									*/
		*isDirectory = ((sourceCatInfo->nodeFlags & kFSNodeIsDirectoryMask) != 0);
			/* destVolParms.vMServerAdr is non-zero for remote volumes	*/
		copyParams->copyingToLocalVolume = (destVolParms.vMServerAdr == 0);
		if( !copyParams->copyingToLocalVolume )
		{
				/* If the destination is on a remote volume, and source and dest are on		*/
				/* the same server, then it might support PBHCopyFileSync					*/
				/* If not, then PBHCopyFileSync won't work									*/

				/* figure out if the volumes support PBHCopyFileSync						*/
			copyParams->volHasCopyFile = ( err == noErr && destVolParms.vMServerAdr == srcVolParms.vMServerAdr ) ?
										   VolHasCopyFile(&srcVolParms) : false;
		}	
	}
	
	if( err == noErr )
		err = SetupDestination( destDir, copyParams->dupeAction, newObjectName, deleteMeRef, isReplacing );
		
	return err;
}

#pragma mark ----- Copy Files -----

/*****************************************************************************/

static OSErr FSCopyFile(	const FSRef			*source,
						 	const FSRef			*destDir,
					 		const FSCatalogInfo	*sourceCatInfo,
					 		const HFSUniStr255	*newFileName,
						 	CopyParams			*copyParams,
					 		FilterParams		*filterParams,
			 				FSRef				*outFileRef,
			 				FSSpec				*outFileSpec )
{
	FSCatalogInfo 	catInfo = *sourceCatInfo;
	FSRef			newFileRef;
	FSSpec			newFileSpec;
	OSErr			err = ( source != NULL && destDir != NULL &&
							copyParams != NULL && filterParams != NULL ) ? noErr : paramErr;
	
							/* If you would like a Pre-Copy filter (i.e to weed out objects	*/
							/* you don't want to copy) you should add it here				*/
	
	if( err == noErr )		/* copy the file over */
		err = CopyFile( source, &catInfo, destDir, newFileName, copyParams, &newFileRef, (filterParams->wantSpec || outFileSpec) ? &newFileSpec : NULL );

		/* Call the IterateFilterProc _after_ the new file was created even if an error occured.	*/
		/* Note: if an error occured above, the FSRef and other info might not be valid				*/
	if( filterParams->filterProcPtr != NULL )
	{
			/* get the extra info the user wanted on the new file that we don't have */
		if( err == noErr && (filterParams->whichInfo & ~kFSCatInfoSettableInfo) != kFSCatInfoNone )
			err = FSGetCatalogInfo( &newFileRef, filterParams->whichInfo & ~kFSCatInfoSettableInfo, &catInfo, NULL, NULL, NULL );	

		err = CallCopyObjectFilterProc( filterParams->filterProcPtr, false, 0, err, &catInfo, &newFileRef, 
										(filterParams->wantSpec) ? &newFileSpec : NULL,
										(filterParams->wantName) ? newFileName : NULL,
										filterParams->yourDataPtr);
	}
	
	if( err == noErr )
	{	
		if( outFileRef != NULL )
			*outFileRef		= newFileRef;
		if( outFileSpec != NULL )
			*outFileSpec	= newFileSpec;
	}
		
	mycheck_noerr(err);

	return err;
}

/*****************************************************************************/

static OSErr CopyFile(	const FSRef			*source,
						FSCatalogInfo		*sourceCatInfo,
					   	const FSRef			*destDir,
					   	const HFSUniStr255	*destName,		/* can be NULL */
					   	CopyParams			*params,
					   	FSRef				*newFile,		/* can be NULL */
					   	FSSpec				*newSpec )		/* can be NULL */
{
	OSErr		err = paramErr;
	
		/* Clear the "inited" bit so that the Finder positions the icon for us.	*/
	((FInfo *)(sourceCatInfo->finderInfo))->fdFlags &= ~kHasBeenInited;

		/* if the volumes support PBHCopyFileSync, try to use it			*/
	if( params->volHasCopyFile == true )
		err = FSUsePBHCopyFile( source, destDir, destName, kTextEncodingUnknown, newFile, newSpec );
			
							/* if PBHCopyFile didn't work or not supported, */
	if( err != noErr )		/* then try old school file transfer			*/
		err = DoCopyFile( source, sourceCatInfo, destDir, destName, params, newFile, newSpec );		

	mycheck_noerr(err);

	return err;
}

/*****************************************************************************/

	/* Wrapper function for PBHCopyFileSync	*/
static OSErr FSUsePBHCopyFile(	const FSRef			*srcFileRef,
								const FSRef			*dstDirectoryRef,
								const HFSUniStr255	*destName,			/* can be NULL */
								TextEncoding		textEncodingHint,
								FSRef				*newRef,			/* can be NULL */
								FSSpec				*newSpec)			/* can be NULL */
{
	FSSpec					srcFileSpec;
	FSCatalogInfo			catalogInfo;
	HParamBlockRec			pb;
	Str255					hfsName;
	OSErr					err = ( srcFileRef != NULL && dstDirectoryRef != NULL ) ? noErr : paramErr;
	
	if( err == noErr )		/* get FSSpec of source FSRef */
		err = FSGetCatalogInfo(srcFileRef, kFSCatInfoNone, NULL, NULL, &srcFileSpec, NULL);
	if( err == noErr )		/* get the destination vRefNum and nodeID (nodeID is the dirID) */
		err = FSGetCatalogInfo(dstDirectoryRef, kFSCatInfoVolume | kFSCatInfoNodeID, &catalogInfo, NULL, NULL, NULL);
	if( err == noErr )		/* gather all the info needed */
	{
		pb.copyParam.ioVRefNum		= srcFileSpec.vRefNum;
		pb.copyParam.ioDirID		= srcFileSpec.parID;
		pb.copyParam.ioNamePtr		= (StringPtr)srcFileSpec.name;
		pb.copyParam.ioDstVRefNum	= catalogInfo.volume;
		pb.copyParam.ioNewDirID		= (long)catalogInfo.nodeID;
		pb.copyParam.ioNewName		= NULL;
		if( destName != NULL )
			err = UniStrToPStr( destName, textEncodingHint, false, hfsName );
		pb.copyParam.ioCopyName		= ( destName != NULL && err == noErr ) ? hfsName : NULL;
	}
	if( err == noErr )			/* tell the server to copy the object */
		err = PBHCopyFileSync(&pb);
	
	if( err == noErr )
	{
		if( newSpec != NULL )	/* caller wants an FSSpec, so make it */		
			myverify_noerr(FSMakeFSSpec( pb.copyParam.ioDstVRefNum, pb.copyParam.ioNewDirID, pb.copyParam.ioCopyName, newSpec));
		if( newRef != NULL )	/* caller wants an FSRef, so make it */
			myverify_noerr(FSMakeFSRef( pb.copyParam.ioDstVRefNum, pb.copyParam.ioNewDirID, pb.copyParam.ioCopyName, newRef));
	}
	
	if( err != paramErr )		/* returning paramErr is ok, it means PBHCopyFileSync was not supported */
		mycheck_noerr(err);

	return err;
}

/*****************************************************************************/

	/* Copies a file referenced by source to the directory referenced by	*/
	/* destDir.  destName is the name the file we are going to copy to the	*/
	/* destination.  sourceCatInfo is the catalog info of the file, which	*/
	/* is passed in as an optimization (we could get it by doing a			*/
	/* FSGetCatalogInfo but the caller has already done that so we might as	*/
	/* well take advantage of that).										*/
	/*																		*/
static OSErr DoCopyFile(const FSRef			*source,
						FSCatalogInfo		*sourceCatInfo,
						const FSRef			*destDir,
						const HFSUniStr255	*destName,
						CopyParams			*params,
						FSRef				*newRef,
						FSSpec				*newSpec )
{
	FSRef	 			dest;
	FSSpec				tmpSpec;
	FSPermissionInfo	originalPermissions;
	OSType				originalFileType = 'xxxx';
	UInt16				originalNodeFlags = kFSCatInfoNone;
	Boolean				getSpec;
	OSErr				err = noErr;

		/* If we're copying to a drop folder, we won't be able to reset this		*/
		/* information once the copy is done, so we don't mess it up in				*/
		/* the first place.  We still clear the locked bit though; items dropped	*/
		/* into a drop folder always become unlocked.								*/
	if (!params->copyingToDropFolder)
	{
			/* Remember to clear the file's type, so the Finder doesn't				*/
			/* look at the file until we're done.									*/
		originalFileType = ((FInfo *) &sourceCatInfo->finderInfo)->fdType;
		((FInfo *) &sourceCatInfo->finderInfo)->fdType = kFirstMagicBusyFiletype;

			/* Remember and clear the file's locked status, so that we can			*/
			/* actually write the forks we're about to create.						*/
		originalNodeFlags = sourceCatInfo->nodeFlags;
	}
	sourceCatInfo->nodeFlags &= ~kFSNodeLockedMask;
	
		/* figure out if we should get the FSSpec to the new file or not			*/
		/* If the caller asked for it, or if we need it for symlinks				*/
	getSpec = ( ( newSpec != NULL ) || ( !params->copyingToDropFolder && originalFileType == 'slnk' && ((FInfo *) &sourceCatInfo->finderInfo)->fdCreator == 'rhap' ) );
	
		/* we need to have user level read/write/execute access to the file we are	*/
		/* going to create otherwise FSCreateFileUnicode will return				*/
		/* -5000 (afpAccessDenied), and the FSRef returned will be invalid, yet		*/
		/* the file is created (size 0k)... bug?									*/
	originalPermissions = *((FSPermissionInfo*)sourceCatInfo->permissions);
	((FSPermissionInfo*)sourceCatInfo->permissions)->mode |= kRWXUserAccessMask;
	
		/* Classic only supports 9.1 and higher, so we don't have to worry			*/
		/* about 2397324															*/
	if( err == noErr )
		err = FSCreateFileUnicode(destDir, destName->length, destName->unicode, kFSCatInfoSettableInfo, sourceCatInfo, &dest, ( getSpec ) ? &tmpSpec : NULL );
	if( err == noErr )	/* Copy the forks over to the new file						*/
		err = CopyForks(source, &dest, params);

		/* Restore the original file type, creation and modification dates,			*/
		/* locked status and permissions.											*/
		/* This is one of the places where we need to handle drop					*/
		/* folders as a special case because this FSSetCatalogInfo will fail for	*/
		/* an item in a drop folder, so we don't even attempt it.					*/
	if (err == noErr && !params->copyingToDropFolder)
	{
		((FInfo *) &sourceCatInfo->finderInfo)->fdType = originalFileType;
		sourceCatInfo->nodeFlags  = originalNodeFlags;
		*((FSPermissionInfo*)sourceCatInfo->permissions) = originalPermissions;

			/* 2796751, FSSetCatalogInfo returns -36 when setting the Finder Info	*/
			/* for a symlink.  To workaround this, when the file is a				*/
			/* symlink (slnk/rhap) we will finish the copy in two steps. First		*/
			/* setting everything but the Finder Info on the file, then calling		*/
			/* FSpSetFInfo to set the Finder Info for the file. I would rather use	*/
			/* an FSRef function to set the Finder Info, but FSSetCatalogInfo is	*/
			/* the only one...  catch-22...											*/
			/*																		*/
			/* The Carbon File Manager always sets the type/creator of a symlink to	*/
			/* slnk/rhap if the file is a symlink we do the two step, if it isn't	*/
			/* we use FSSetCatalogInfo to do all the work.							*/
		if ((originalFileType == 'slnk') && (((FInfo *) &sourceCatInfo->finderInfo)->fdCreator == 'rhap'))
		{								/* Its a symlink							*/
										/* set all the info, except the Finder info	*/
			err = FSSetCatalogInfo(&dest, kFSCatInfoNodeFlags | kFSCatInfoPermissions, sourceCatInfo);
			if ( err == noErr )			/* set the Finder Info to that file			*/
				err = FSpSetFInfo( &tmpSpec, ((FInfo *) &sourceCatInfo->finderInfo) );
		}
		else							/* its a regular file 						*/
			err = FSSetCatalogInfo(&dest, kFSCatInfoNodeFlags | kFSCatInfoFinderInfo | kFSCatInfoPermissions, sourceCatInfo);
	}
	
		/* If we created the file and the copy failed, try to clean up by			*/
		/* deleting the file we created.  We do this because, while it's			*/
		/* possible for the copy to fail halfway through and the File Manager 		*/
		/* doesn't really clean up that well in that case, we *really* don't want	*/
		/* any half-created files being left around.								*/
		/* if the file already existed, we don't want to delete it					*/
	if( err == noErr || err == dupFNErr )
	{			/* if everything was fine, then return the new file Spec/Ref		*/
		if( newRef != NULL )
			*newRef = dest;
		if( newSpec != NULL )
			*newSpec = tmpSpec;
	}
	else	
		myverify_noerr( FSDeleteObjects(&dest) );

	mycheck_noerr(err);

	return err;
}

/*****************************************************************************/

#pragma mark ----- Copy Folders -----

static OSErr FSCopyFolder(	const FSRef			*source,
							const FSRef			*destDir,
					 		const FSCatalogInfo	*sourceCatInfo,
							const HFSUniStr255	*newObjectName,
							CopyParams			*copyParams, 
							FilterParams		*filterParams,
							ItemCount			maxLevels,
							FSRef				*outDirRef,
							FSSpec				*outDirSpec )
{
	FSCopyFolderGlobals	folderGlobals;
	FolderListData		*tmpListData		= NULL;
	FSCatalogInfo		catInfo = *sourceCatInfo;
	FSRef				newDirRef;
	FSSpec				newDirSpec;
	OSErr				err;

							/* setup folder globals	*/
	folderGlobals.catInfoList		= (FSCatalogInfo*)	NewPtr( sizeof( FSCatalogInfo )	* kNumObjects );
	folderGlobals.srcRefList		= (FSRef*)			NewPtr( sizeof( FSRef )			* kNumObjects );
	folderGlobals.nameList			= (HFSUniStr255*)	NewPtr( sizeof( HFSUniStr255 )	* kNumObjects );
	folderGlobals.folderListIter	= NULL;
	folderGlobals.copyParams		= copyParams;
	folderGlobals.filterParams		= filterParams;
	folderGlobals.maxLevels			= maxLevels;
	folderGlobals.currentLevel		= 0;

							/* if any of the NewPtr calls failed, we MUST bail */
	err								= ( folderGlobals.catInfoList	!= NULL &&
										folderGlobals.srcRefList	!= NULL &&
										folderGlobals.nameList		!= NULL ) ? noErr : memFullErr;

							/* init the linked list we will use to keep track of the folders */
	InitLinkedList( &folderGlobals.folderList, MyDisposeDataProc );

	if( err == noErr && !copyParams->copyingToDropFolder )
		err = GetMagicBusyCreateDate( &catInfo.createDate );
	if( err == noErr )		/* create the directory */
		err = DoCreateFolder( source, destDir, &catInfo, newObjectName, folderGlobals.copyParams, &newDirRef, (filterParams->wantSpec || outDirSpec ) ? &newDirSpec : NULL );
	
		/* Note: if an error occured above, the FSRef and other info might not be valid */
	if( filterParams->filterProcPtr != NULL )
	{
			/* get the info the user wanted about the source directory we don't have */
		if( err == noErr && (filterParams->whichInfo & ~kFSCatInfoSettableInfo) != kFSCatInfoNone )
			err = FSGetCatalogInfo(&newDirRef, filterParams->whichInfo & ~kFSCatInfoSettableInfo, &catInfo, NULL, NULL, NULL);

		err = CallCopyObjectFilterProc(filterParams->filterProcPtr, false, folderGlobals.currentLevel,
									   err, &catInfo, &newDirRef,
									   ( filterParams->wantSpec ) ? &newDirSpec : NULL,
									   ( filterParams->wantName ) ? newObjectName : NULL,
									     filterParams->yourDataPtr);
	}
	if( err == noErr )		/* create the memory for this folder */
		err = ( ( tmpListData = (FolderListData*) NewPtr( sizeof( FolderListData ) ) ) != NULL ) ? noErr : MemError();
	if( err == noErr )
	{		/* setup the folder info */
		tmpListData->sourceDirRef	= *source;
		tmpListData->destDirRef		= newDirRef;
		tmpListData->level			= folderGlobals.currentLevel;
			/* add this folder to the list to give ProcessFolderList something to chew on */
		err = AddToTail( &folderGlobals.folderList, tmpListData );
		if( err == noErr )			/* tmpListData added successfully	*/
			err = ProcessFolderList( &folderGlobals );
		else						/* error occured, so dispose of memory */
			DisposePtr( (char*) tmpListData );
	}
	
	dwarning(("\n%s -- %u folders were found\n", __FUNCTION__, (unsigned int)GetNumberOfItems( &folderGlobals.folderList ) ));
	
		/* when we're done destroy the list and free up any memory we allocated */
	DestroyList( &folderGlobals.folderList );

		/* now that the copy is complete, we can set things back to normal	*/
		/* for the directory we just created.								*/
		/* We have to do this only for the top directory of the copy		*/
		/* all subdirectories were created all at once						*/
	if( err == noErr && !folderGlobals.copyParams->copyingToDropFolder )
		err = FSSetCatalogInfo( &newDirRef, kFSCatInfoCreateDate | kFSCatInfoPermissions, sourceCatInfo );
					
		/* Copy went as planned, and caller wants an FSRef/FSSpec to the new directory */		
	if( err == noErr )
	{
		if( outDirRef != NULL)
			*outDirRef = newDirRef;
		if( outDirSpec != NULL )
			*outDirSpec = newDirSpec;
	}

		/* clean up for space and safety, who me? */
	if( folderGlobals.catInfoList )
		DisposePtr( (char*) folderGlobals.catInfoList );
	if( folderGlobals.srcRefList )
		DisposePtr( (char*) folderGlobals.srcRefList );
	if( folderGlobals.nameList )
		DisposePtr( (char*) folderGlobals.nameList );

	mycheck_noerr(err);	

	return ( err );
}

/*****************************************************************************/

	/* We now store a list of all the folders/subfolders we encounter in the source	*/
	/* Each node in the list contains an FSRef to the source, an FSRef to the 		*/
	/* mirror folder in the destination, and the level in the source that folder	*/
	/* is on.  This is done so that we can use FSGetCatalogInfoBulk to its full		*/
	/* potential (getting items in bulk).  We copy the source one folder at a time.	*/
	/* Copying over the contents of each folder before we continue on to the next	*/
	/* folder in the list.  This allows us to use the File Manager's own caching	*/
	/* system to our advantage.														*/
static OSErr ProcessFolderList( FSCopyFolderGlobals *folderGlobals )
{
	FolderListData		*folderListData;
	OSErr				err = noErr;
	
		/* iterate through the list of folders and copy over each one individually	*/
	for( InitIterator( &folderGlobals->folderList, &folderGlobals->folderListIter ); folderGlobals->folderListIter != NULL && err == noErr; Next( &folderGlobals->folderListIter ) )
	{
			/* Get the data for this folder */
		folderListData = (FolderListData*) GetData( folderGlobals->folderListIter );
		if( folderListData != NULL )
		{
			#if DEBUG && !TARGET_API_MAC_OS8
			{
				char	path[1024];
				myverify_noerr(FSRefMakePath( &(folderListData->sourceDirRef),	(unsigned char*)path, 1024 ));
				dwarning(("\n\n%s -- Copying contents of\n\t%s\n", __FUNCTION__, path));
				myverify_noerr(FSRefMakePath( &(folderListData->destDirRef),	(unsigned char*)path, 1024 ));
				dwarning(("\t\tto\n\t%s\n", path));
			}	
			#endif
			
				/* stuff the data into our globals */
			folderGlobals->sourceDirRef	= &(folderListData->sourceDirRef);
			folderGlobals->destDirRef	= &(folderListData->destDirRef);
			folderGlobals->currentLevel = folderListData->level;
			
				/* Copy over this folder and add any subfolders to our list of folders	*/
				/* so they will get processed later										*/
			err = CopyFolder( folderGlobals );
		}
	}
	
	return err;
}

/*****************************************************************************/

	/* Copy the contents of the source into the destination.  If any subfolders */
	/* are found, add them to a local list of folders during the loop stage		*/
	/* Once the copy is done, insert the local list into the global list right	*/
	/* after the current position in the list.  This is done so we don't jump	*/
	/* all over the disk getting the different folders to copy					*/
static OSErr CopyFolder( FSCopyFolderGlobals *folderGlobals )
{
	GenLinkedList	tmpList;
	FolderListData	*tmpListData = NULL;
	FilterParams	*filterPtr = folderGlobals->filterParams;
	FSIterator		iterator;
	FSRef			newRef;
	FSSpec			newSpec;
	UInt32			actualObjects;
	OSErr			err,
					junkErr;
	int				i;

		/* Init the local list */
	InitLinkedList( &tmpList, MyDisposeDataProc);

	err = FSOpenIterator( folderGlobals->sourceDirRef, kFSIterateFlat, &iterator );
	if( err == noErr )
	{
		do
		{
				/* grab a bunch of objects (kNumObjects) from this folder and copy them over */
			err = FSGetCatalogInfoBulk( iterator, kNumObjects, &actualObjects, &filterPtr->containerChanged,
										kFSCatInfoSettableInfo, folderGlobals->catInfoList, folderGlobals->srcRefList,
										NULL, folderGlobals->nameList );
			if( ( err == noErr || err == errFSNoMoreItems ) &&
				( actualObjects != 0 ) )
			{			
				dwarning(("%s -- actualObjects retrieved from FSGetCatalogInfoBulk: %u\n",__FUNCTION__, (unsigned int)actualObjects ));
			
					/* iterate over the objects actually returned */
				for( i = 0; i < actualObjects; i++ )
				{
						/* Any errors in here will be passed to the filter proc				*/
						/* we don't want an error in here to prematurely cancel the copy	*/

						/* If you would like a Pre-Copy filter (i.e to weed out objects		*/
						/* you don't want to copy) you should add it here					*/

						/* Is the new object a directory?	*/				
					if( ( folderGlobals->catInfoList[i].nodeFlags & kFSNodeIsDirectoryMask ) != 0 )
					{		/* yes */
						junkErr = CreateFolder( &folderGlobals->srcRefList[i], folderGlobals->destDirRef,
												&folderGlobals->catInfoList[i], &folderGlobals->nameList[i],
												folderGlobals->copyParams, &newRef, (filterPtr->wantSpec) ? &newSpec : NULL );
							/* If maxLevels is zero, we aren't checking levels				*/
							/* If currentLevel+1 < maxLevels, add this folder to the list	*/
						if( folderGlobals->maxLevels == 0 || (folderGlobals->currentLevel + 1) < folderGlobals->maxLevels )
						{
							if( junkErr == noErr )		/* Create memory for folder list data	*/
								junkErr = ( ( tmpListData = (FolderListData*) NewPtr( sizeof( FolderListData ) ) ) != NULL ) ? noErr : MemError();
							if( junkErr == noErr )
							{							/* Setup the folder list data			*/
								tmpListData->sourceDirRef	= folderGlobals->srcRefList[i];
								tmpListData->destDirRef		= newRef;
								tmpListData->level			= folderGlobals->currentLevel + 1;
								
														/* Add it to the local list				*/
								junkErr = AddToTail( &tmpList, tmpListData );
							}
								/* If an error occured and memory was created, we need to dispose of it	*/
								/* since it was not added to the list									*/
							if( junkErr != noErr && tmpListData != NULL )
								DisposePtr( (char*) tmpListData );
						}
					}
					else
					{		/* no */
						junkErr = CopyFile(	&folderGlobals->srcRefList[i], &folderGlobals->catInfoList[i], 
											folderGlobals->destDirRef, &folderGlobals->nameList[i], 
											folderGlobals->copyParams, &newRef, ( filterPtr->wantSpec ) ? &newSpec : NULL );
					}
					
						/* Note: if an error occured above, the FSRef and other info might not be valid */
					if( filterPtr->filterProcPtr != NULL )
					{
						if( junkErr == noErr && (filterPtr->whichInfo & ~kFSCatInfoSettableInfo) != kFSCatInfoNone )	/* get the extra info about the new object that the user wanted that we don't already have */
							junkErr = FSGetCatalogInfo( &newRef, filterPtr->whichInfo & ~kFSCatInfoSettableInfo, &folderGlobals->catInfoList[i], NULL, NULL, NULL );

						err = CallCopyObjectFilterProc(	filterPtr->filterProcPtr, filterPtr->containerChanged,
														folderGlobals->currentLevel, junkErr,
														&folderGlobals->catInfoList[i], &newRef,
														( filterPtr->wantSpec ) ? &newSpec : NULL,
														( filterPtr->wantName ) ? &folderGlobals->nameList[i] : NULL,
														filterPtr->yourDataPtr);
					}
				}
			}
		}while( err == noErr );
	
			/* errFSNoMoreItems is OK - it only means we hit the end of this level */
			/* afpAccessDenied is OK too - it only means we cannot see inside the directory */
		if( err == errFSNoMoreItems || err == afpAccessDenied )
			err = noErr;

			/* Insert the local list of folders from the current folder into our global list.  Even	*/
			/* if no items were added to the local list (due to error, or empty folder), InsertList	*/
			/* handles it correctly.  We add the local list even if an error occurred.  It will get	*/
			/* disposed of when the global list is destroyed.  Doesn't hurt to have a couple extra	*/
			/* steps when we're going to bail anyways.												*/
		InsertList( &folderGlobals->folderList, &tmpList, folderGlobals->folderListIter );	
			
			/* Close the FSIterator (closing an open iterator should never fail) */
		(void) FSCloseIterator(iterator);
	}

	mycheck_noerr( err );	
	
	return err;
}

/*****************************************************************************/

	/* Determines whether the destination directory is equal to the source	*/
	/* item, or whether it's nested inside the source item.  Returns a		*/
	/* errFSDestInsideSource if that's the case.  We do this to prevent		*/
	/* endless recursion while copying.										*/
	/*																		*/
static OSErr CheckForDestInsideSrc(	const FSRef	*source,
									const FSRef	*destDir)
{
	FSRef			thisDir = *destDir;
	FSCatalogInfo	thisDirInfo;
	Boolean			done = false;
	OSErr			err;
	
	do
	{
		err = FSCompareFSRefs(source, &thisDir);
		if (err == noErr)
			err = errFSDestInsideSource;
		else if (err == diffVolErr)
		{
			err = noErr;
			done = true;
		} 
		else if (err == errFSRefsDifferent)
		{
			/* This is somewhat tricky.  We can ask for the parent of thisDir	*/
			/* by setting the parentRef parameter to FSGetCatalogInfo but, if	*/
			/* thisDir is the volume's FSRef, this will give us back junk.		*/
			/* So we also ask for the parent's dir ID to be returned in the		*/
			/* FSCatalogInfo record, and then check that against the node		*/
			/* ID of the root's parent (ie 1).  If we match that, we've made	*/
			/* it to the top of the hierarchy without hitting source, so		*/
			/* we leave with no error.											*/
			
			err = FSGetCatalogInfo(&thisDir, kFSCatInfoParentDirID, &thisDirInfo, NULL, NULL, &thisDir);
			if( ( err == noErr ) && ( thisDirInfo.parentDirID == fsRtParID ) )
				done = true;
		}
	} while ( err == noErr && ! done );
	
	mycheck_noerr( err );	

	return err;
}

/*****************************************************************************/

#pragma mark ----- Copy Forks -----

	/* This is where the majority of the work is done.  I special cased		*/
	/* DropBoxes in order to use FSIterateForks to its full potential for	*/
	/* the more common case (read/write permissions).  It also simplifies	*/
	/* the code to have it seperate.										*/
static OSErr CopyForks(	const FSRef		*source,
						const FSRef		*dest,
						CopyParams		*params)
{
	OSErr			err;

	err = ( !params->copyingToDropFolder ) ?	CopyForksToDisk		( source, dest, params ) :
												CopyForksToDropBox	( source, dest, params );

	mycheck_noerr( err );	

	return err;
}

	/* Open each fork individually and copy them over to the destination				*/
static OSErr CopyForksToDisk(	const FSRef	*source,
								const FSRef	*dest,
								CopyParams	*params )
{
	HFSUniStr255	forkName;
	CatPositionRec	iterator;
	SInt64			forkSize;
	SInt16			srcRefNum,
					destRefNum;
	OSErr			err;
	
		/* need to initialize the iterator before using it */
	iterator.initialize = 0;
	
	do
	{
		err = FSIterateForks( source, &iterator, &forkName, &forkSize, NULL );

			/* Create the fork.  Note: Data and Resource forks are automatically		*/
			/* created when the file is created.  FSCreateFork returns noErr for them	*/
			/* We also want to create the fork even if there is no data to preserve		*/
			/* empty forks																*/
		if( err == noErr )
			err = FSCreateFork( dest, forkName.length, forkName.unicode );

			/* Mac OS 9.0 has a bug (in the AppleShare external file system,			*/
			/* I think) [2410374] that causes FSCreateFork to return an errFSForkExists	*/
			/* error even though the fork is empty.  The following code swallows		*/
			/* the error (which is harmless) in that case.								*/
		if( err == errFSForkExists && !params->copyingToLocalVolume )
			err = noErr;

			/* The remainder of this code only applies if there is actual data			*/
			/* in the source fork.														*/

		if( err == noErr && forkSize > 0 )
		{
			destRefNum = srcRefNum = 0;
			
									/* Open the destination fork	*/
			err = FSOpenFork(dest, forkName.length, forkName.unicode, fsWrPerm, &destRefNum);
			if( err == noErr )		/* Open the source fork			*/
				err = FSOpenFork(source, forkName.length, forkName.unicode, fsRdPerm, &srcRefNum);
			if( err == noErr )		/* Write the fork to disk		*/
				err = WriteFork( srcRefNum, destRefNum, params, forkSize );

			if( destRefNum	!= 0 )	/* Close the destination fork	*/
				myverify_noerr( FSCloseFork( destRefNum ) );
			if( srcRefNum	!= 0 )	/* Close the source fork		*/
				myverify_noerr( FSCloseFork( srcRefNum ) );
		}					
	}
	while( err == noErr );
	
	if( err == errFSNoMoreItems )
		err = noErr;

	mycheck_noerr( err );
		
	return err;
}

	/* If we're copying to a DropBox, we have to handle the copy process a little		*/
	/* differently then when we are copying to a regular folder. 						*/
static OSErr CopyForksToDropBox(	const FSRef		*source,
									const FSRef		*dest,
									CopyParams		*params )
{
	GenLinkedList	forkList;
	GenIteratorPtr	pIter;
	ForkTrackerPtr	forkPtr;
	SInt16			srcRefNum;
	OSErr			err;

	InitLinkedList( &forkList, MyCloseForkProc );
	
		/* If we're copying into a drop folder, open up all of those forks.	*/
		/* We have to do this because once we've started writing to a fork	*/
		/* in a drop folder, we can't open any more forks.					*/
	err = OpenAllForks( dest, &forkList );
		
		/* Copy each fork over to the destination							*/
	for( InitIterator( &forkList, &pIter ); pIter != NULL && err == noErr; Next( &pIter ) )
	{
		srcRefNum	= 0;
		forkPtr		= GetData( pIter );
								/* Open the source fork		*/
		err = FSOpenFork(source, forkPtr->forkName.length, forkPtr->forkName.unicode, fsRdPerm, &srcRefNum);
		if( err == noErr )		/* Write the data over		*/
			err = WriteFork( srcRefNum, forkPtr->forkDestRefNum, params, forkPtr->forkSize );

		if( srcRefNum	!= 0 )	/* Close the source fork	*/
			myverify_noerr( FSCloseFork( srcRefNum ) );
	}
		/* we're done, so destroy the list even if an error occured				*/
		/* the DisposeDataProc will close any open forks						*/
	DestroyList( &forkList );

	mycheck_noerr( err );

	return err;
}

/*****************************************************************************/

	/* Create and open all the forks in the destination file.  We need to do this when 		*/
	/* we're copying into a drop folder, where you must open all the forks before starting	*/
	/* to write to any of them.																*/
	/*																						*/
	/* IMPORTANT:  If it fails, this routine won't close forks that opened successfully.	*/
	/* 		Make sure that the DisposeDataProc for the forkList closed any open forks		*/
	/* 		Or you close each one manually before destroying the list						*/
static OSErr OpenAllForks(	const FSRef		*dest,
							GenLinkedList	*forkList )
{
	ForkTrackerPtr	forkPtr;
	HFSUniStr255	forkName;
	CatPositionRec  iterator;
	SInt64			forkSize;
	OSErr			err = ( dest != NULL && forkList != NULL ) ? noErr : paramErr;
	
		/* need to initialize the iterator before using it */
	iterator.initialize = 0;
	
		/* Iterate over the list of forks	*/
	while( err == noErr )
	{
		forkPtr = NULL;	/* init forkPtr */
		
		err = FSIterateForks( dest, &iterator, &forkName, &forkSize, NULL );
		if( err == noErr )
			err = ( forkPtr = (ForkTrackerPtr) NewPtr( sizeof( ForkTracker ) ) ) != NULL ? noErr : MemError();
		if( err == noErr )
		{
			forkPtr->forkName		= forkName;
			forkPtr->forkSize		= forkSize;
			forkPtr->forkDestRefNum	= 0;

				/* Create the fork.  Note: Data and Resource forks are automatically		*/
				/* created when the file is created.  FSCreateFork returns noErr for them	*/
				/* We also want to create the fork even if there is no data to preserve		*/
				/* empty forks																*/
			err = FSCreateFork( dest, forkName.length, forkName.unicode );

				/* Swallow afpAccessDenied because this operation causes the external file	*/
				/* system compatibility shim in Mac OS 9 to generate a GetCatInfo request	*/
				/* to the AppleShare external file system, which in turn causes an AFP		*/
				/* GetFileDirParms request on the wire, which the AFP server bounces with	*/
				/* afpAccessDenied because the file is in a drop folder.  As there's no		*/
				/* native support for non-classic forks in current AFP, there's no way I	*/
				/* can decide how I should handle this in a non-test case.  So I just		*/
				/* swallow the error and hope that when native AFP support arrives, the		*/
				/* right thing will happen.													*/
			if( err == afpAccessDenied )
				err = noErr;
				
				/* only open the fork if the fork has some data								*/
			if( err == noErr && forkPtr->forkSize > 0 )
				err = FSOpenFork( dest, forkPtr->forkName.length, forkPtr->forkName.unicode, fsWrPerm, &forkPtr->forkDestRefNum );

				/* if everything is ok, add this fork to the list							*/
			if( err == noErr )
				err = AddToTail( forkList, forkPtr );
		}
 
		if( err != noErr && forkPtr != NULL )
			DisposePtr( (char*) forkPtr );
	}

	if( err == errFSNoMoreItems )
		err = noErr;

	mycheck_noerr( err );	

	return err;
}

/*****************************************************************************/

	/* Writes the fork from the source, references by srcRefNum, to the destination fork	*/
	/* references by destRefNum																*/
static OSErr WriteFork(	const SInt16		srcRefNum,
						const SInt16		destRefNum,
						const CopyParams	*params,
						const SInt64		forkSize )
{
	UInt64			bytesRemaining;
	UInt64			bytesToReadThisTime;
	UInt64			bytesToWriteThisTime;
	OSErr			err;
	

		/* Here we create space for the entire fork on the destination volume.				*/	
		/* FSAllocateFork has the right semantics on both traditional Mac OS				*/
		/* and Mac OS X.  On traditional Mac OS it will allocate space for the				*/
		/* file in one hit without any other special action.  On Mac OS X,					*/
		/* FSAllocateFork is preferable to FSSetForkSize because it prevents				*/
		/* the system from zero filling the bytes that were added to the end				*/
		/* of the fork (which would be waste because we're about to write over				*/
		/* those bytes anyway.																*/
	err = FSAllocateFork(destRefNum, kFSAllocNoRoundUpMask, fsFromStart, 0, forkSize, NULL);

		/* Copy the file from the source to the destination in chunks of					*/
		/* no more than params->copyBufferSize bytes.  This is fairly						*/
		/* boring code except for the bytesToReadThisTime/bytesToWriteThisTime				*/
		/* distinction.  On the last chunk, we round bytesToWriteThisTime					*/
		/* up to the next 512 byte boundary and then, after we exit the loop,				*/
		/* we set the file's EOF back to the real location (if the fork size				*/
		/* is not a multiple of 512 bytes).													*/
		/* 																					*/
		/* This technique works around a 'bug' in the traditional Mac OS File Manager,		*/
		/* where the File Manager will put the last 512-byte block of a large write into	*/
		/* the cache (even if we specifically request no caching) if that block is not		*/
		/* full. If the block goes into the cache it will eventually have to be				*/
		/* flushed, which causes sub-optimal disk performance.								*/
		/*																					*/
		/* This is only done if the destination volume is local.  For a network				*/
		/* volume, it's better to just write the last bytes directly.						*/
		/*																					*/
		/* This is extreme over-optimization given the other limits of this					*/
		/* sample, but I will hopefully get to the other limits eventually.					*/
	bytesRemaining = forkSize;
	while( err == noErr && bytesRemaining != 0 )
	{
		if( bytesRemaining > params->copyBufferSize )
		{
			bytesToReadThisTime  = 	params->copyBufferSize;
			bytesToWriteThisTime = 	bytesToReadThisTime;
		}
		else 
		{
			bytesToReadThisTime  = 	bytesRemaining;
			bytesToWriteThisTime =	( params->copyingToLocalVolume )		  ?
									( (bytesRemaining + 0x01FF ) & ~0x01FF ) : bytesRemaining;
		}
		
		err = FSReadFork( srcRefNum, fsAtMark + noCacheMask, 0, bytesToReadThisTime, params->copyBuffer, NULL );
		if( err == noErr )
			err = FSWriteFork( destRefNum, fsAtMark + noCacheMask, 0, bytesToWriteThisTime, params->copyBuffer, NULL );
		if( err == noErr )
			bytesRemaining -= bytesToReadThisTime;
	}
	
	if (err == noErr && params->copyingToLocalVolume && ( forkSize & 0x01FF ) != 0 )
		err = FSSetForkSize( destRefNum, fsFromStart, forkSize );

	return err;
}

/*****************************************************************************/

#pragma mark ----- Calculate Buffer Size -----

	/* This routine calculates the appropriate buffer size for				*/
	/* the given volParms.  It's a simple composition of FSGetVolParms		*/
	/* BufferSizeForVolSpeed.												*/
static UInt32 CalcBufferSizeForVol(const GetVolParmsInfoBuffer *volParms, UInt32 volParmsSize)
{
	UInt32	volumeBytesPerSecond = 0;

	/* Version 1 of the GetVolParmsInfoBuffer included the vMAttrib		*/
	/* field, so we don't really need to test actualSize.  A noErr		*/
	/* result indicates that we have the info we need.  This is			*/
	/* just a paranoia check.											*/
	
	mycheck(volParmsSize >= offsetof(GetVolParmsInfoBuffer, vMVolumeGrade));

	/* On the other hand, vMVolumeGrade was not introduced until		*/
	/* version 2 of the GetVolParmsInfoBuffer, so we have to explicitly	*/
	/* test whether we got a useful value.								*/
	
	if( ( volParmsSize >= offsetof(GetVolParmsInfoBuffer, vMForeignPrivID) ) &&
		( volParms->vMVolumeGrade <= 0 ) ) 
	{
		volumeBytesPerSecond = -volParms->vMVolumeGrade;
	}

	return BufferSizeForVolSpeed(volumeBytesPerSecond);
}

/*****************************************************************************/

	/* Calculate an appropriate copy buffer size based on the volumes		*/
	/* rated speed.  Our target is to use a buffer that takes 0.25			*/
	/* seconds to fill.  This is necessary because the volume might be		*/
	/* mounted over a very slow link (like ARA), and if we do a 256 KB		*/
	/* read over an ARA link we'll block the File Manager queue for			*/
	/* so long that other clients (who might have innocently just			*/
	/* called PBGetCatInfoSync) will block for a noticeable amount of time.	*/
	/*																		*/
	/* Note that volumeBytesPerSecond might be 0, in which case we assume	*/
	/* some default value.													*/
static UInt32 BufferSizeForVolSpeed(UInt32 volumeBytesPerSecond)
{
	ByteCount bufferSize;
	
	if (volumeBytesPerSecond == 0)
		bufferSize = kDefaultCopyBufferSize;
	else
	{	/* We want to issue a single read that takes 0.25 of a second,	*/
		/* so devide the bytes per second by 4.							*/
		bufferSize = volumeBytesPerSecond / 4;
	}
	
		/* Round bufferSize down to 512 byte boundary. */
	bufferSize &= ~0x01FF;
	
		/* Clip to sensible limits. */
	if (bufferSize < kMinimumCopyBufferSize)
		bufferSize = kMinimumCopyBufferSize;
	else if (bufferSize > kMaximumCopyBufferSize)
		bufferSize = kMaximumCopyBufferSize;
		
	return bufferSize;
}

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
	FSDeleteObjectGlobals	theGlobals;
	
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

/*****************************************************************************/

#pragma mark ----- Utilities -----

	/* Figures out if the given directory is a drop box or not		*/
	/* if it is, the Copy Engine will behave slightly differently	*/
static OSErr IsDropBox(	const FSRef* source,
						Boolean *isDropBox )
{
	FSCatalogInfo			tmpCatInfo;
	FSSpec					sourceSpec;
	Boolean					isDrop = false;
	OSErr					err;
	
		/* get info about the destination, and an FSSpec to it for PBHGetDirAccess */
	err = FSGetCatalogInfo(source, kFSCatInfoNodeFlags | kFSCatInfoPermissions, &tmpCatInfo, NULL, &sourceSpec, NULL);
	if( err == noErr )	/* make sure the source is a directory */
		err = ((tmpCatInfo.nodeFlags & kFSNodeIsDirectoryMask) != 0) ? noErr : errFSNotAFolder;
	if( err == noErr )
	{
		HParamBlockRec	hPB;

		BlockZero( &hPB, sizeof( HParamBlockRec ) );

		hPB.accessParam.ioNamePtr		= sourceSpec.name;
		hPB.accessParam.ioVRefNum		= sourceSpec.vRefNum;
		hPB.accessParam.ioDirID			= sourceSpec.parID;
		
			/* This is the official way (reads: the way X Finder does it) to figure	*/
			/* out the current users access privileges to a given directory			*/
		err = PBHGetDirAccessSync(&hPB);
		if( err == noErr )	/* its a drop folder if the current user only has write access */
			isDrop = (hPB.accessParam.ioACAccess & kPrivilegesMask) == kioACAccessUserWriteMask;
		else if ( err == paramErr )
		{
			/* There is a bug (2908703) in the Classic File System (not OS 9.x or Carbon)	*/
			/* on 10.1.x where PBHGetDirAccessSync sometimes returns paramErr even when the	*/
			/* data passed in is correct.  This is a workaround/hack for that problem,		*/
			/* but is not as accurate.														*/
			/* Basically, if "Everyone" has only Write/Search access then its a drop folder	*/
			/* that is the most common case when its a drop folder							*/
			FSPermissionInfo *tmpPerm = (FSPermissionInfo *)tmpCatInfo.permissions;
			isDrop = ((tmpPerm->mode & kRWXOtherAccessMask) == kDropFolderValue);
			err = noErr;
		}
	}

	*isDropBox = isDrop;

	mycheck_noerr( err );
	
	return err;
}

/*****************************************************************************/

	/* The copy engine is going to set the item's creation date			*/
	/* to kMagicBusyCreationDate while it's copying the item.			*/
	/* But kMagicBusyCreationDate is an old-style 32-bit date/time,		*/
	/* while the HFS Plus APIs use the new 64-bit date/time.  So		*/
	/* we have to call a happy UTC utilities routine to convert from	*/
	/* the local time kMagicBusyCreationDate to a UTCDateTime			*/
	/* gMagicBusyCreationDate, which the File Manager will store		*/
	/* on disk and which the Finder we read back using the old			*/
	/* APIs, whereupon the File Manager will convert it back			*/
	/* to local time (and hopefully get the kMagicBusyCreationDate		*/
	/* back!).															*/
static OSErr GetMagicBusyCreateDate( UTCDateTime *date )
{
	static	UTCDateTime	magicDate	= { 0, 0xDEADBEEF, 0 };
    OSErr		err		= ( date != NULL ) ? noErr : paramErr;
	
	if( err == noErr && magicDate.lowSeconds == 0xDEADBEEF )
		err = ConvertLocalTimeToUTC( kMagicBusyCreationDate, &magicDate.lowSeconds );
	if( err == noErr )
		*date = magicDate;
		
	mycheck_noerr( err );	

	return err;		
}

/*****************************************************************************/

static OSErr FSGetVRefNum(	const FSRef		*ref,
							FSVolumeRefNum	*vRefNum)
{
	FSCatalogInfo	catalogInfo;
	OSErr			err = ( ref != NULL && vRefNum != NULL ) ? noErr : paramErr;

	if( err == noErr )	/* get the volume refNum from the FSRef */
		err = FSGetCatalogInfo(ref, kFSCatInfoVolume, &catalogInfo, NULL, NULL, NULL);
	if( err == noErr )
		*vRefNum = catalogInfo.volume;
		
	mycheck_noerr( err );

	return err;
}

/*****************************************************************************/ 

static OSErr FSGetVolParms(	FSVolumeRefNum			volRefNum,
							UInt32					bufferSize,
							GetVolParmsInfoBuffer	*volParmsInfo,
							UInt32					*actualInfoSize)		/*	Can Be NULL	*/
{
	HParamBlockRec	pb;
	OSErr			err = ( volParmsInfo != NULL ) ? noErr : paramErr;
		
	if( err == noErr )
	{
		pb.ioParam.ioNamePtr = NULL;
		pb.ioParam.ioVRefNum = volRefNum;
		pb.ioParam.ioBuffer = (Ptr)volParmsInfo;
		pb.ioParam.ioReqCount = (SInt32)bufferSize;
		err = PBHGetVolParmsSync(&pb);
	}
		/* return number of bytes the file system returned in volParmsInfo buffer */
	if( err == noErr && actualInfoSize != NULL)
		*actualInfoSize = (UInt32)pb.ioParam.ioActCount;

	mycheck_noerr( err );	

	return ( err );
}

/*****************************************************************************/

/* Converts a unicode string to a PString										*/
/* If your code is only for OS X, you can use CFString functions to do all this */
/* Since this sample code supports OS 9.1 -> OS X, I have to do this the 		*/
/* old fashioned way.															*/
static OSErr UniStrToPStr(	const HFSUniStr255	*uniStr,
							TextEncoding		 textEncodingHint,
							Boolean				 isVolumeName,
							Str255				 pStr )
{
	UnicodeMapping		uMapping;
	UnicodeToTextInfo	utInfo;
	ByteCount			unicodeByteLength = 0;
	ByteCount			unicodeBytesConverted;
	ByteCount			actualPascalBytes;
	OSErr				err = (uniStr != NULL && pStr != NULL) ? noErr : paramErr;

		/* make sure output is valid in case we get errors or there's nothing to convert */
	pStr[0] = 0;

	if( err == noErr )
		unicodeByteLength = uniStr->length * sizeof(UniChar); /* length can be zero, which is fine */
	if( err == noErr && unicodeByteLength != 0 )
	{
			/* if textEncodingHint is kTextEncodingUnknown, get a "default" textEncodingHint */
		if ( kTextEncodingUnknown == textEncodingHint )
		{
			ScriptCode			script;
			RegionCode			region;
			
			script = (ScriptCode)GetScriptManagerVariable(smSysScript);
			region = (RegionCode)GetScriptManagerVariable(smRegionCode);
			err = UpgradeScriptInfoToTextEncoding(script, kTextLanguageDontCare, 
													region, NULL, &textEncodingHint );
			if ( err == paramErr )
			{		/* ok, ignore the region and try again */
				err = UpgradeScriptInfoToTextEncoding(script, kTextLanguageDontCare,
														kTextRegionDontCare, NULL, 
														&textEncodingHint );
			}
			if ( err != noErr )			/* ok... try something */
				textEncodingHint = kTextEncodingMacRoman; 		
		}
		
		uMapping.unicodeEncoding	= CreateTextEncoding(	kTextEncodingUnicodeV2_0,
															kUnicodeCanonicalDecompVariant, 
															kUnicode16BitFormat);
		uMapping.otherEncoding		= GetTextEncodingBase(textEncodingHint);
		uMapping.mappingVersion		= kUnicodeUseHFSPlusMapping;
	
		err = CreateUnicodeToTextInfo(&uMapping, &utInfo);
		if( err == noErr )
		{
			err = ConvertFromUnicodeToText(	utInfo, unicodeByteLength, uniStr->unicode, kUnicodeLooseMappingsMask,
												0, NULL, 0, NULL,	/* offsetCounts & offsetArrays */
												isVolumeName ? kHFSMaxVolumeNameChars : kHFSPlusMaxFileNameChars,
												&unicodeBytesConverted, &actualPascalBytes, &pStr[1]);
		}
		if( err == noErr )
			pStr[0] = actualPascalBytes;
		
			/* verify the result in debug builds -- there's really not anything you can do if it fails */
		myverify_noerr(DisposeUnicodeToTextInfo(&utInfo));				
	}
	
	mycheck_noerr( err );
	
	return ( err );	
}

/*****************************************************************************/

	/* Yeah I know there is FSpMakeFSRef, but this way I don't have to	*/
	/* actually have an FSSpec created to make the FSRef, and this is	*/
	/* what FSpMakeFSRef does anyways									*/
static OSErr FSMakeFSRef(	FSVolumeRefNum		volRefNum,
							SInt32				dirID,
							ConstStr255Param	name,
							FSRef				*ref )
{
	FSRefParam	pb;
	OSErr		err = ( ref != NULL ) ? noErr : paramErr;
	
	if( err == noErr )
	{
		pb.ioVRefNum = volRefNum;
		pb.ioDirID = dirID;
		pb.ioNamePtr = (StringPtr)name;
		pb.newRef = ref;
		err = PBMakeFSRefSync(&pb);
	}
	
	mycheck_noerr( err );	
		
	return ( err );
}

/*****************************************************************************/

	/* This checks the destination to see if an object of the same name as the source	*/
	/* exists or not.  If it does we have to special handle the DupeActions				*/
	/*																					*/
	/* If kDupeActionReplace we move aside the object by renameing it to ".DeleteMe"	*/
	/* so that it will be invisible (X only), and give a suggestion on what to do with	*/
	/* it if for some unknown reason it survives the copy and the user finds it.  This	*/
	/* rename is mainly done to handle the case where the source is in the destination	*/
	/* and the user wants to replace.  Basically keeping the source around throughout	*/
	/* the copy, deleting it afterwards.  Its also done cause its a good idea not to	*/
	/* dispose of the existing object in case the copy fails							*/
	/*																					*/
	/* If kDupeActionRename, we create a unique name for the new object and pass		*/
	/* it back to the caller															*/
static OSErr SetupDestination(	const FSRef			*destDir,
								const DupeAction	dupeAction,
								HFSUniStr255		*sourceName,
								FSRef				*deleteMeRef,
								Boolean				*isReplacing )
{
	FSRef	tmpRef;
	OSErr	err;

		/* check if an object of the same name already exists in the destination */
	err = FSMakeFSRefUnicode( destDir, sourceName->length, sourceName->unicode, kTextEncodingUnknown, &tmpRef );
	if( err == noErr )
	{													/* if the user wants to replace the existing		*/
														/* object, rename it to .DeleteMe first.  Delete it	*/
		if( dupeAction == kDupeActionReplace )			/* only after copying the new one successfully		*/
		{
			err = FSRenameUnicode( &tmpRef, 9, (UniChar*)"\0.\0D\0e\0l\0e\0t\0e\0M\0e", kTextEncodingMacRoman, deleteMeRef );
			*isReplacing = ( err == noErr ) ? true : false;
		}
		else if( dupeAction == kDupeActionRename )		/* if the user wants to just rename it				*/
			err = GetUniqueName( destDir, sourceName );	/* then we get a unique name for the new object		*/
	}
	else if ( err == fnfErr )							/* if no object exists then							*/
		err = noErr;									/* continue with no error							*/
	
	return err;
}

/*****************************************************************************/

	/* Given a directory and a name, GetUniqueName will check if an object	*/
	/* with the same name already exists, and if it does it will create		*/
	/* a new, unique name for and return it.								*/
	/* it simply appends a number to the end of the name.  It is not		*/
	/* fool proof, and it is limited...  I'll take care of that in a		*/
	/* later release														*/
	/* If anyone has any suggestions/better techniques I would love to hear */
	/* about them															*/
static OSErr GetUniqueName(	const FSRef		*destDir,
							HFSUniStr255	*sourceName )
{
	HFSUniStr255	tmpName = *sourceName;
	FSRef			tmpRef;
	unsigned char	hexStr[17] = "123456789";	/* yeah, only 9...  I'm lazy, sosumi */
	long			count = 0;
	int				index;
	OSErr			err;	

		/* find the dot, if there is one */
	for( index = tmpName.length; index >= 0 && tmpName.unicode[index] != (UniChar) '.'; index-- ) { /* Do Nothing */ }		
	
	if( index <= 0) /* no dot or first char is a dot (invisible file), so append to end of name */
		index = tmpName.length;
	else			/* shift the extension up two spots to make room for our digits */
		BlockMoveData( tmpName.unicode + index, tmpName.unicode + index + 2, (tmpName.length - index) * 2 );
		
		/* add the space to the name */
	tmpName.unicode[ index ] = (UniChar)' ';
		/* we're adding two characters to the name */
	tmpName.length += 2;

	do {	/* add the digit to the name */
		tmpName.unicode[ index + 1 ] = hexStr[count];
			/* check if the file with this new name already exists */
		err = FSMakeFSRefUnicode( destDir, tmpName.length, tmpName.unicode, kTextEncodingUnknown, &tmpRef );
		count++;
	} while( err == noErr && count < 10 );

	if( err == fnfErr )
	{
		err = noErr;
		*sourceName = tmpName;
	}
	
	return err;
}

/*****************************************************************************/

static OSErr GetObjectName( const FSRef			*sourceRef,
							HFSUniStr255		*sourceName,		/* can be NULL */
							TextEncoding		*sourceEncoding )	/* can be NULL */
{
	FSCatalogInfo		catInfo;
	FSCatalogInfoBitmap	whichInfo = (sourceEncoding != NULL) ? kFSCatInfoTextEncoding : kFSCatInfoNone;
	OSErr				err;
	
	err = FSGetCatalogInfo( sourceRef, whichInfo, &catInfo, sourceName, NULL, NULL );
	if( err == noErr && sourceEncoding != NULL )
		*sourceEncoding = catInfo.textEncodingHint;
	
	return err;
}

/*****************************************************************************/

static OSErr CreateFolder(	const FSRef			*sourceRef,
							const FSRef			*destDirRef,
							const FSCatalogInfo	*catalogInfo,
							const HFSUniStr255	*folderName,
							CopyParams			*params,
							FSRef				*newFSRefPtr,
							FSSpec				*newFSSpecPtr )
{
	FSCatalogInfo		tmpCatInfo;
	FSPermissionInfo	origPermissions;
	OSErr				err = ( sourceRef != NULL && destDirRef != NULL && catalogInfo != NULL &&
								folderName != NULL && newFSRefPtr != NULL ) ? noErr : paramErr;

	if( err == noErr )
	{		/* store away the catInfo, create date and permissions on the orig folder */
		tmpCatInfo = *catalogInfo;
		origPermissions	= *((FSPermissionInfo*)catalogInfo->permissions);
	}
	if( err == noErr )			/* create the new folder */
		err = DoCreateFolder( sourceRef, destDirRef, &tmpCatInfo, folderName, params, newFSRefPtr, newFSSpecPtr ); 
	if( err == noErr && !params->copyingToDropFolder )
	{			/* if its not a drop box, set the permissions on the new folder */
		*((FSPermissionInfo*)tmpCatInfo.permissions)	= origPermissions;
		err = FSSetCatalogInfo( newFSRefPtr, kFSCatInfoPermissions, &tmpCatInfo );
	}
	
	mycheck_noerr( err );
	
	return err;
}

/*****************************************************************************/

static OSErr DoCreateFolder(const FSRef			*sourceRef,
							const FSRef			*destDirRef,
							const FSCatalogInfo	*catalogInfo,
							const HFSUniStr255	*folderName,
							CopyParams			*params,
							FSRef			 	*newFSRefPtr,
							FSSpec				*newFSSpecPtr)
{
	FSCatalogInfo	catInfo = *catalogInfo;
	OSErr			err;
	
		/* Clear the "inited" bit so that the Finder positions the icon for us. */
	((FInfo *)(catInfo.finderInfo))->fdFlags &= ~kHasBeenInited;
		
		/* we need to have user level read/write/execute access to the folder we are going to create,	*/
		/* otherwise FSCreateDirectoryUnicode will return -5000 (afpAccessDenied),						*/
		/* and the FSRef returned will be invalid, yet the folder is created...  bug?					*/
	((FSPermissionInfo*) catInfo.permissions)->mode |= kRWXUserAccessMask;
	
	err = FSCreateDirectoryUnicode(	destDirRef, folderName->length,
									folderName->unicode, kFSCatInfoSettableInfo,
									&catInfo, newFSRefPtr,
									newFSSpecPtr, NULL);
									
		/* With the new APIs, folders can have forks as well as files.  Before	*/
		/* we start copying items in the folder, we	must copy over the forks	*/
		/* Currently, MacOS doesn't support any file systems that have forks in	*/
		/* folders, but the API supports it so (for possible future				*/
		/* compatability) I kept this in here.									*/
	if( err == noErr )
		err = CopyForks( sourceRef, newFSRefPtr, params );
	
	mycheck_noerr( err );

	return err;
}

/*****************************************************************************/

	/* This is the DisposeDataProc that is used by the GenLinkedList in FSCopyFolder	*/
	/* Simply disposes of the data we created and returns								*/
static pascal void MyDisposeDataProc( void *pData )
{
	if( pData != NULL )
		DisposePtr( (char*) pData );
}

/*****************************************************************************/

	/* This is the DisposeDataProc that is used by the GenLinkedList in CopyItemForks	*/
	/* Simply closes the resource fork (if opened, != 0) and disposes of the memory		*/
static pascal void MyCloseForkProc( void *pData )
{
	SInt16		refNum;

	if( pData == NULL )
		return;
		
	refNum = ((ForkTrackerPtr)pData)->forkDestRefNum;
	if( refNum != 0 )
		myverify_noerr( FSCloseFork( refNum ) );	/* the fork was opened, so close it */
	
	DisposePtr( (char*) pData );	
}
