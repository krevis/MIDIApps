#ifndef __MessageQueue_h__
#define __MessageQueue_h__

#include <CoreFoundation/CoreFoundation.h>

#if defined(__cplusplus)
extern "C" {
#endif
    
typedef void (*MessageQueueHandler)(CFTypeRef objectFromQueue, void *refCon);

void CreateMessageQueue(MessageQueueHandler inHandler, void *inHandlerRefCon);
void DestroyMessageQueue();

void AddToMessageQueue(CFTypeRef objectToAdd);

#if defined(__cplusplus)
}
#endif
    
#endif // __MessageQueue_h__
