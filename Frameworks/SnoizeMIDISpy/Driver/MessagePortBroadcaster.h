#ifndef __MessagePortBroadcaster_h__
#define __MessagePortBroadcaster_h__

#include <CoreFoundation/CoreFoundation.h>


class MessagePortBroadcaster;

class MessagePortBroadcasterDelegate {
public:
    MessagePortBroadcasterDelegate() 		{ }
    virtual ~MessagePortBroadcasterDelegate()	{ }

    virtual void BroadcasterListenerCountChanged(MessagePortBroadcaster *broadcaster, bool hasListeners) = 0;
};


class MessagePortBroadcaster {
public:
                                MessagePortBroadcaster(CFStringRef broadcasterName, MessagePortBroadcasterDelegate *delegate);
    virtual 		~MessagePortBroadcaster();

    void		Broadcast(CFDataRef data, SInt32 channel);

    CFDataRef		NextListenerIdentifier();
    void		AddListener(CFDataRef listenerIdentifierData);
    void		ChangeListenerChannelStatus(CFDataRef messageData, Boolean shouldAdd);
    
    void		RemoveListenerWithRemotePort(CFMessagePortRef remotePort);

private:
    MessagePortBroadcasterDelegate	*mDelegate;
    CFStringRef				mBroadcasterName;
    CFMessagePortRef			mLocalPort;
    CFRunLoopSourceRef			mRunLoopSource;
    UInt32					mNextListenerIdentifier;

    CFMutableDictionaryRef		mListenersByIdentifier;
    CFMutableDictionaryRef		mIdentifiersByListener;
    CFMutableDictionaryRef		mListenerArraysByChannel;
    pthread_mutex_t				mListenerStructuresMutex;
};

#endif // __MessagePortBroadcaster_h__
