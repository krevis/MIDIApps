#ifndef __MOREFILESX__
#define __MOREFILESX__

#ifndef __MACTYPES__
#include <MacTypes.h>
#endif

#ifndef __FILES__
#include <Files.h>
#endif

#if PRAGMA_ONCE
#pragma once
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if PRAGMA_IMPORT
#pragma import on
#endif


/*****************************************************************************/

    OSErr
    FSDeleteContainerContents(
                              const FSRef *container);
    /*
     The FSDeleteContainerContents function deletes the contents of a container
     directory. All files and subdirectories in the specified container are
     deleted. If a locked file or directory is encountered, it is unlocked and
     then deleted. If any unexpected errors are encountered,
	FSDeleteContainerContents quits and returns to the caller.
 	container			--> FSRef to a directory.
 	__________
 	Also see:	FSDeleteContainer
 */


/*****************************************************************************/


#ifdef PRAGMA_IMPORT_OFF
#pragma import off
#elif PRAGMA_IMPORT
#pragma import reset
#endif

#ifdef __cplusplus
}
#endif

#endif /* __MOREFILESX__ */
