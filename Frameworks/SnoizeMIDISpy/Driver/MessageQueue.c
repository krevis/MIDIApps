/*
 Copyright (c) 2001-2011, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

#include "MessageQueue.h"
#include <pthread.h>


static MessageQueueHandler handler = NULL;
static void *handlerRefCon = NULL;

static CFRunLoopRef mainThreadRunLoop = NULL;
static CFRunLoopSourceRef runLoopSource = NULL;

static pthread_mutex_t queueLock;
static CFMutableArrayRef queueArray = NULL;

static void mainThreadRunLoopSourceCallback(void *info);


void CreateMessageQueue(MessageQueueHandler inHandler, void *inHandlerRefCon)
{
    // We should be running in the main thread of the process.

    CFRunLoopSourceContext context;
    int pthreadError;

    handler = inHandler;
    handlerRefCon = inHandlerRefCon;
    
    // Create a simple run loop source
    context.version = 0;
    context.info = NULL;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    context.equal = NULL;
    context.hash = NULL;
    context.schedule = NULL;
    context.cancel = NULL;
    context.perform = mainThreadRunLoopSourceCallback;
    
    runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    if (!runLoopSource) {
#if DEBUG
        printf("SetUpMessageQueue: CFRunLoopSourceCreate failed\n");
#endif
        return;
    }        
    
    // Add the run loop source to this run loop
    mainThreadRunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(mainThreadRunLoop, runLoopSource, kCFRunLoopDefaultMode);

    // Create lock
    pthreadError = pthread_mutex_init(&queueLock, NULL);
    if (pthreadError) {
#if DEBUG
        printf("SetUpMessageQueue: pthread_mutex_init failed (%d)\n", pthreadError);
#endif
        return;
    }

    // Create array for a queue structure
    queueArray = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    if (!queueArray) {
#if DEBUG
        printf("SetUpMessageQueue: CFArrayCreateMutable failed\n");
#endif
        return;        
    }
}

void DestroyMessageQueue(void)
{
    if (runLoopSource) {
        CFRunLoopSourceInvalidate(runLoopSource);
        CFRelease(runLoopSource);
        runLoopSource = NULL;
    }

    if (queueArray) {
        pthread_mutex_destroy(&queueLock);
        CFRelease(queueArray);
    }
}

void AddToMessageQueue(CFTypeRef objectToAdd)
{
    int pthreadError;
    
    // take the lock on the message queue
    pthreadError = pthread_mutex_lock(&queueLock);
    if (pthreadError) {
#if DEBUG
        printf("AddToMessageQueue: pthread_mutex_lock failed (%d)\n", pthreadError);
#endif
        return;        
    }
    
    // add the object to the queue
    CFArrayAppendValue(queueArray, objectToAdd);

    // release the lock
    pthreadError = pthread_mutex_unlock(&queueLock);
    if (pthreadError) {
#if DEBUG
        printf("AddToMessageQueue: pthread_mutex_unlock failed (%d)\n", pthreadError);
#endif
        return;
    }
    
    // signal the run loop source, so it runs
    CFRunLoopSourceSignal(runLoopSource);
    // and make sure the run loop wakes up right away (otherwise it may take a few seconds)
    CFRunLoopWakeUp(mainThreadRunLoop);
}

void mainThreadRunLoopSourceCallback(void *info)
{
    int pthreadError;
    CFArrayRef copiedQueueArray;
    CFIndex queueCount, queueIndex;
    
    // take the lock on the message queue
    pthreadError = pthread_mutex_lock(&queueLock);
    if (pthreadError) {
#if DEBUG
        printf("AddToMessageQueue: pthread_mutex_lock failed (%d)\n", pthreadError);
#endif
        return;
    }

    // copy the array of queued objects,
    copiedQueueArray = CFArrayCreateCopy(kCFAllocatorDefault, queueArray);
    // and remove the queued objects
    CFArrayRemoveAllValues(queueArray);

    // release the lock
    pthreadError = pthread_mutex_unlock(&queueLock);
    if (pthreadError) {
#if DEBUG
        printf("AddToMessageQueue: pthread_mutex_unlock failed (%d)\n", pthreadError);
#endif
        CFRelease(copiedQueueArray);
        return;
    }
    
    // for each object in the array, call a function to process it
    queueCount = CFArrayGetCount(copiedQueueArray);
    for (queueIndex = 0; queueIndex < queueCount; queueIndex++) {
        CFTypeRef object;

        object = (CFDictionaryRef)CFArrayGetValueAtIndex(copiedQueueArray, queueIndex);
        handler(object, handlerRefCon);        
    }

    CFRelease(copiedQueueArray);
    
    return;
}
