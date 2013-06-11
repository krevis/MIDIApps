/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
    mListenersByIdentifier = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    mIdentifiersByListener = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
    mListenerArraysByChannel = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
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
        fprintf(stderr, "MessagePortBroadcaster: broadcast(%p, %p)\n", data, (void *)channel);
    #endif
    
    pthread_mutex_lock(&mListenerStructuresMutex);

    listeners = (CFArrayRef)CFDictionaryGetValue(mListenerArraysByChannel, (void *)channel);
    if (listeners) {
        listenerIndex = CFArrayGetCount(listeners);
    
        while (listenerIndex--) {
            CFMessagePortRef listenerPort = (CFMessagePortRef)CFArrayGetValueAtIndex(listeners, listenerIndex);
            CFMessagePortSendRequest(listenerPort, 0, data, 300, 0, NULL, NULL);
        }
    }

    pthread_mutex_unlock(&mListenerStructuresMutex);
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
    returnedData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&mNextListenerIdentifier, sizeof(UInt32));

    return returnedData;
}

void	MessagePortBroadcaster::AddListener(CFDataRef listenerIdentifierData)
{
    // The listener has created a local port on its side, and we need to create a remote port for it.
    // No reply is necessary.

    const UInt8 *dataBytes;
    UInt32 listenerIdentifier;
    CFStringRef listenerPortName;
    CFMessagePortRef remotePort;

    if (!listenerIdentifierData || CFDataGetLength(listenerIdentifierData) != sizeof(UInt32))
        return;

    dataBytes = CFDataGetBytePtr(listenerIdentifierData);
    if (!dataBytes)
        return;

    listenerIdentifier = *(const UInt32 *)dataBytes;
    listenerPortName = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@-%u"), mBroadcasterName, (unsigned int)listenerIdentifier);

    remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, listenerPortName);
    if (remotePort) {
        CFMessagePortSetInvalidationCallBack(remotePort, MessagePortWasInvalidated);

        pthread_mutex_lock(&mListenerStructuresMutex);
        CFDictionarySetValue(mListenersByIdentifier, (void *)listenerIdentifier, (void *)remotePort);
        CFDictionarySetValue(mIdentifiersByListener, (void *)remotePort, (void *)listenerIdentifier);
        pthread_mutex_unlock(&mListenerStructuresMutex);

        CFRelease(remotePort);

        // TODO we don't really want to do this here -- we want to do it when the client adds a channel
        if (mDelegate && CFDictionaryGetCount(mListenersByIdentifier) == 1)
            mDelegate->BroadcasterListenerCountChanged(this, true);
    }

    CFRelease(listenerPortName);
}

void	MessagePortBroadcaster::ChangeListenerChannelStatus(CFDataRef messageData, Boolean shouldAdd)
{
    // From the message data given, take out the identifier of the listener, and the channel it is concerned with.
    // Then find the remote message port corresponding to that identifier.
    // Then find the array of listeners for this channel (creating it if necessary), and add/remove the remote port from the array.
    // No reply is necessary.
    
    const UInt8 *dataBytes;
    UInt32 identifier;
    SInt32 channel;
    CFMessagePortRef remotePort;
    CFMutableArrayRef channelListeners;

    if (!messageData || CFDataGetLength(messageData) != sizeof(UInt32) + sizeof(SInt32))
        return;
    dataBytes = CFDataGetBytePtr(messageData);
    if (!dataBytes)
        return;
    identifier = *(UInt32 *)dataBytes;
    channel = *(SInt32 *)(dataBytes + sizeof(UInt32));

    remotePort = (CFMessagePortRef)CFDictionaryGetValue(mListenersByIdentifier, (void *)identifier);
    if (!remotePort)
        return;

    pthread_mutex_lock(&mListenerStructuresMutex);
        
    channelListeners = (CFMutableArrayRef)CFDictionaryGetValue(mListenerArraysByChannel, (void *)channel);
    if (!channelListeners && shouldAdd) {
        channelListeners = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
        if (channelListeners) {
            CFDictionarySetValue(mListenerArraysByChannel, (void *)channel, channelListeners);
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
    UInt32 identifier;

    pthread_mutex_lock(&mListenerStructuresMutex);

    // Remove this listener from our dictionaries
    const void* ptrId = CFDictionaryGetValue(mIdentifiersByListener, (void *)remotePort);
#if __LP64__
    identifier = (uintptr_t)ptrId & 0xFFFFFFFFUL;
#else
    identifier = (UInt32)ptrId;
#endif
    CFDictionaryRemoveValue(mListenersByIdentifier, (void *)identifier);
    CFDictionaryRemoveValue(mIdentifiersByListener, (void *)remotePort);

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
