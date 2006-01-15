/*
	File:		GenLinkedList.h
	
	Contains:	Linked List utility routines prototypes

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

	Copyright © 2003-2004 Apple Computer, Inc., All Rights Reserved
*/


#ifndef __GENLINKEDLIST__
#define __GENLINKEDLIST__

#ifdef __cplusplus
extern "C" {
#endif

#if TARGET_API_MAC_OSX || defined( __APPLE_CC__ )
#include	<CoreServices/CoreServices.h>
#endif

/* This is a quick, simple and generic linked list implementation.  I tried		*/
/* to setup the code so that you could use any linked list implementation you	*/
/* want.  They just	need to support these few functions.						*/

typedef void*	GenIteratorPtr;
typedef void*	GenDataPtr;

	/* This is a callback that is called from DestroyList for each node in the	*/
	/* list.  It gives the caller the oportunity to free any memory they might	*/
	/* allocated in each node.													*/
typedef CALLBACK_API( void , DisposeDataProcPtr ) ( GenDataPtr pData );

#define CallDisposeDataProc( userRoutine, pData )	(*(userRoutine))((pData))

struct GenLinkedList
{
	GenDataPtr				pHead;				/* Pointer to the head of the list							*/
	GenDataPtr				pTail;				/* Pointer to the tail of the list							*/
	ItemCount				NumberOfItems;		/* Number of items in the list (mostly for debugging)		*/
	DisposeDataProcPtr		DisposeProcPtr;		/* rountine called to dispose of caller data, can be NULL	*/
};
typedef struct GenLinkedList	GenLinkedList;

void 		InitLinkedList	( GenLinkedList *pList, DisposeDataProcPtr disposeProcPtr );
ItemCount	GetNumberOfItems( GenLinkedList *pList );
OSErr		AddToTail		( GenLinkedList *pList, GenDataPtr pData );
void		InsertList		( GenLinkedList *pDestList, GenLinkedList *pSrcList, GenIteratorPtr pIter );
void		DestroyList		( GenLinkedList	*pList );

void		InitIterator	( GenLinkedList *pList, GenIteratorPtr *pIter );
void		Next			( GenIteratorPtr *pIter );
GenDataPtr	GetData			( GenIteratorPtr pIter );

#ifdef __cplusplus
}
#endif

#endif