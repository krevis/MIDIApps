/*
 Copyright (c) 2001-2018, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

#include "MessagePortBroadcaster.h"

#include "MIDISpyShared.h"
#include <pthread.h>


// Private function declarations
CFDataRef LocalMessagePortCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) __attribute__((cf_returns_retained));
void MessagePortWasInvalidated(CFMessagePortRef messagePort, void *info);
void RemoveRemotePortFromChannelArray(const void *key, const void *value, void *context);


// NOTE This static variable is a dumb workaround. See comment in MessagePortWasInvalidated().
static MessagePortBroadcaster *sOneBroadcaster = NULL;


MessagePortBroadcaster::MessagePortBroadcaster(CFStringRef broadcasterName, MessagePortBroadcasterDelegate *delegate) :
    mDelegate(delegate),
    mBroadcasterName(NULL),
    mLocalPort(NULL),
    mRunLoopSource(NULL),
    mNextListenerIdentifier(0),
    mListenersByIdentifier(NULL),
    mIdentifiersByListener(NULL),
    mListenerArraysByChannel(NULL)
{
    CFMessagePortContext messagePortContext = { 0, (void *)this, NULL, NULL, NULL };

    #if DEBUG
        fprintf(stderr, "MessagePortBroadcaster: creating\n");
    #endif
        
    sOneBroadcaster = this;
    
    if (!broadcasterName)
        broadcasterName = CFSTR("Unknown Broadcaster");
    mBroadcasterName = CFStringCreateCopy(kCFAllocatorDefault, broadcasterName);
    if (!mBroadcasterName)
        goto abort;

    // Create a local port for remote listeners to talk to us with
    #if DEBUG
        fprintf(stderr, "MessagePortBroadcaster: creating local port\n");
    #endif
    mLocalPort = CFMessagePortCreateLocal(kCFAllocatorDefault, mBroadcasterName, LocalMessagePortCallBack, &messagePortContext, FALSE);
    if (!mLocalPort) {
        #if DEBUG
            fprintf(stderr, "MessagePortBroadcaster: couldn't create local port!\n");
        #endif
        goto abort;
    }

    // And add it to the current run loop
    mRunLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, mLocalPort, 0);
    if (!mRunLoopSource) {
        #if DEBUG
            fprintf(stderr, "MessagePortBroadcaster: couldn't create run loop source for local port!\n");
        #endif        
        goto abort;
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), mRunLoopSource, kCFRunLoopDefaultMode);

    // Create structures to keep track of our listeners
    mListenersByIdentifier = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    mIdentifiersByListener = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    mListenerArraysByChannel = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (!mListenersByIdentifier || !mIdentifiersByListener || !mListenerArraysByChannel) {
        #if DEBUG
            fprintf(stderr, "MessagePortBroadcaster: couldn't create a listener dictionary!\n");
        #endif
        goto abort;        
    }

    pthread_mutex_init(&mListenerStructuresMutex, NULL);

    return;

abort:
    if (mListenerArraysByChannel)
        CFRelease(mListenerArraysByChannel);

    if (mIdentifiersByListener)
        CFRelease(mIdentifiersByListener);

    if (mListenersByIdentifier)
        CFRelease(mListenersByIdentifier);

    if (mRunLoopSource) {
        CFRunLoopSourceInvalidate(mRunLoopSource);
        CFRelease(mRunLoopSource);
    }

    if (mLocalPort) {
        CFMessagePortInvalidate(mLocalPort);
        CFRelease(mLocalPort);
    }
    
    if (mBroadcasterName)
        CFRelease(mBroadcasterName);

    throw MessagePortBroadcasterException();
}

MessagePortBroadcaster::~MessagePortBroadcaster()
{
    #if DEBUG
        fprintf(stderr, "MessagePortBroadcaster: destroying\n");
    #endif

    // As we delete our dictionaries, any leftover remote CFMessagePorts will get invalidated.
    // But we want to bypass the usual invalidation code (since we're just taking everything
    // down anyway), so we set sOneBroadcaster to NULL. MessagePortWasInvalidated() will
    // still get called, but it won't be able to call back into this C++ object.
    // NOTE When restructuring to get rid of sOneBroadcaster, you'll need to rethink this.
    sOneBroadcaster = NULL;

    pthread_mutex_destroy(&mListenerStructuresMutex);

    if (mListenerArraysByChannel)
        CFRelease(mListenerArraysByChannel);

    if (mIdentifiersByListener)
        CFRelease(mIdentifiersByListener);

    if (mListenersByIdentifier)
        CFRelease(mListenersByIdentifier);

    if (mRunLoopSource) {
        CFRunLoopSourceInvalidate(mRunLoopSource);
        CFRelease(mRunLoopSource);
    }

    if (mLocalPort) {
        CFMessagePortInvalidate(mLocalPort);
        CFRelease(mLocalPort);
    }

    if (mBroadcasterName)
        CFRelease(mBroadcasterName);    
}

void MessagePortBroadcaster::Broadcast(CFDataRef data, SInt32 channel)
{
    CFArrayRef listeners;
    CFIndex listenerIndex;

    #if DEBUG && 0
        fprintf(stderr, "MessagePortBroadcaster: broadcast(%p, %d)\n", data, channel);
    #endif

    CFNumberRef channelNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &channel);
    if (channelNumber) {
        pthread_mutex_lock(&mListenerStructuresMutex);

        listeners = (CFArrayRef)CFDictionaryGetValue(mListenerArraysByChannel, channelNumber);
        if (listeners) {
            listenerIndex = CFArrayGetCount(listeners);
        
            while (listenerIndex--) {
                CFMessagePortRef listenerPort = (CFMessagePortRef)CFArrayGetValueAtIndex(listeners, listenerIndex);
                CFMessagePortSendRequest(listenerPort, 0, data, 300, 0, NULL, NULL);
            }
        }

        pthread_mutex_unlock(&mListenerStructuresMutex);

        CFRelease(channelNumber);
    }
}


//
// Private functions and methods
//

CFDataRef LocalMessagePortCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
    MessagePortBroadcaster *broadcaster = (MessagePortBroadcaster *)info;
    CFDataRef result = NULL;

    #if DEBUG && 0
        fprintf(stderr, "MessagePortBroadcaster: message port callback(msgid=%ld)\n", msgid);
    #endif
    
    switch (msgid) {
        case kSpyingMIDIDriverGetNextListenerIdentifierMessageID:
            result = broadcaster->NextListenerIdentifier();
            break;

        case kSpyingMIDIDriverAddListenerMessageID:
            broadcaster->AddListener(data);
            break;

        case kSpyingMIDIDriverConnectDestinationMessageID:
            broadcaster->ChangeListenerChannelStatus(data, true);
            break;

        case kSpyingMIDIDriverDisconnectDestinationMessageID:
            broadcaster->ChangeListenerChannelStatus(data, false);
            break;

        default:
            break;        
    }

    return result;
}

CFDataRef	MessagePortBroadcaster::NextListenerIdentifier()
{
    // Client is starting up; it wants to know what identifier to use (so it can name its local port).
    // We give it that data in a reply.

    CFDataRef returnedData;

    mNextListenerIdentifier++;
    returnedData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&mNextListenerIdentifier, sizeof(SInt32));

    return returnedData;
}

void	MessagePortBroadcaster::AddListener(CFDataRef listenerIdentifierData)
{
    // The listener has created a local port on its side, and we need to create a remote port for it.
    // No reply is necessary.

    const UInt8 *dataBytes;
    SInt32 listenerIdentifier;
    CFNumberRef listenerIdentifierNumber;
    CFStringRef listenerPortName;
    CFMessagePortRef remotePort;

    if (!listenerIdentifierData || CFDataGetLength(listenerIdentifierData) != sizeof(SInt32))
        return;

    dataBytes = CFDataGetBytePtr(listenerIdentifierData);
    if (!dataBytes)
        return;

    listenerIdentifier = *(const SInt32 *)dataBytes;
    listenerIdentifierNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &listenerIdentifier);
    if (!listenerIdentifierNumber)
        return;

    listenerPortName = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@-%d"), mBroadcasterName, listenerIdentifier);

    remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, listenerPortName);
    if (remotePort) {
        CFMessagePortSetInvalidationCallBack(remotePort, MessagePortWasInvalidated);

        pthread_mutex_lock(&mListenerStructuresMutex);
        CFDictionarySetValue(mListenersByIdentifier, listenerIdentifierNumber, remotePort);
        CFDictionarySetValue(mIdentifiersByListener, remotePort, listenerIdentifierNumber);
        pthread_mutex_unlock(&mListenerStructuresMutex);

        CFRelease(remotePort);

        // TODO we don't really want to do this here -- we want to do it when the client adds a channel
        if (mDelegate && CFDictionaryGetCount(mListenersByIdentifier) == 1)
            mDelegate->BroadcasterListenerCountChanged(this, true);
    }

    CFRelease(listenerPortName);
    CFRelease(listenerIdentifierNumber);
}

void	MessagePortBroadcaster::ChangeListenerChannelStatus(CFDataRef messageData, Boolean shouldAdd)
{
    // From the message data given, take out the identifier of the listener, and the channel it is concerned with.
    // Then find the remote message port corresponding to that identifier.
    // Then find the array of listeners for this channel (creating it if necessary), and add/remove the remote port from the array.
    // No reply is necessary.
    
    const UInt8 *dataBytes;
    SInt32 identifier;
    SInt32 channel;
    CFMessagePortRef remotePort;
    CFMutableArrayRef channelListeners;
    CFNumberRef listenerIdentifierNumber;

    if (!messageData || CFDataGetLength(messageData) != sizeof(SInt32) + sizeof(SInt32))
        return;
    dataBytes = CFDataGetBytePtr(messageData);
    if (!dataBytes)
        return;
    identifier = *(SInt32 *)dataBytes;
    channel = *(SInt32 *)(dataBytes + sizeof(SInt32));

    listenerIdentifierNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &identifier);
    if (!listenerIdentifierNumber)
        return;

    remotePort = (CFMessagePortRef)CFDictionaryGetValue(mListenersByIdentifier, listenerIdentifierNumber);
    CFRelease(listenerIdentifierNumber);

    if (!remotePort)
        return;

    CFNumberRef channelNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &channel);
    if (!channelNumber)
        return;

    pthread_mutex_lock(&mListenerStructuresMutex);

    channelListeners = (CFMutableArrayRef)CFDictionaryGetValue(mListenerArraysByChannel, channelNumber);
    if (!channelListeners && shouldAdd) {
        channelListeners = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
        if (channelListeners) {
            CFDictionarySetValue(mListenerArraysByChannel, channelNumber, channelListeners);
            CFRelease(channelListeners);
        }
    }

    if (shouldAdd) {
        CFArrayAppendValue(channelListeners, remotePort);
    } else if (channelListeners) {
        CFIndex index;

        index = CFArrayGetFirstIndexOfValue(channelListeners, CFRangeMake(0, CFArrayGetCount(channelListeners)), remotePort);
        if (index != kCFNotFound)
            CFArrayRemoveValueAtIndex(channelListeners, index);
    }

    pthread_mutex_unlock(&mListenerStructuresMutex);

    CFRelease(channelNumber);
}

void MessagePortWasInvalidated(CFMessagePortRef messagePort, void *info)
{
    // NOTE: The info pointer provided to this function is useless. CFMessagePort provides no way to set it for remote ports.
    // Thus, we have to assume we have one MessagePortBroadcaster, which we look up statically. Lame!
    // TODO come up with a better solution to this

    #if DEBUG && 0
        fprintf(stderr, "MessagePortBroadcaster: remote port was invalidated\n");
    #endif

    if (sOneBroadcaster)
        sOneBroadcaster->RemoveListenerWithRemotePort(messagePort);
}

void	MessagePortBroadcaster::RemoveListenerWithRemotePort(CFMessagePortRef remotePort)
{
    pthread_mutex_lock(&mListenerStructuresMutex);

    // Remove this listener from our dictionaries
    CFNumberRef listenerNumber = (CFNumberRef)CFDictionaryGetValue(mIdentifiersByListener, remotePort);
    CFDictionaryRemoveValue(mListenersByIdentifier, listenerNumber);
    CFDictionaryRemoveValue(mIdentifiersByListener, remotePort);

    // Also go through the listener array for each channel and remove remotePort from there too
    CFDictionaryApplyFunction(mListenerArraysByChannel, RemoveRemotePortFromChannelArray, remotePort);    

    pthread_mutex_unlock(&mListenerStructuresMutex);

    // TODO we don't really want to do this here -- we want to do it when a client removes a channel
    if (mDelegate && CFDictionaryGetCount(mListenersByIdentifier) == 0)
        mDelegate->BroadcasterListenerCountChanged(this, false);    
}

void RemoveRemotePortFromChannelArray(const void *key, const void *value, void *context)
{
    // We don't care about the key (it's a channel number)
    CFMutableArrayRef listenerArray = (CFMutableArrayRef)value;
    CFMessagePortRef remotePort = (CFMessagePortRef)context;
    CFIndex index;

    index = CFArrayGetFirstIndexOfValue(listenerArray, CFRangeMake(0, CFArrayGetCount(listenerArray)), remotePort);
    if (index != kCFNotFound)
        CFArrayRemoveValueAtIndex(listenerArray, index);
}
