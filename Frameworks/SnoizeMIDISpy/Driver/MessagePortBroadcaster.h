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

    void		Broadcast(CFDataRef dataToBroadcast);

    CFDataRef		NextSequenceNumber();
    void		AddListener(CFDataRef listenerSequenceNumberData);

    bool		HasListeners();
    
private:
    MessagePortBroadcasterDelegate *mDelegate;
    CFStringRef		mBroadcasterName;
    CFMessagePortRef	mListenerRegistrationLocalPort;
    CFRunLoopSourceRef	mListenerRegistrationRunLoopSource;
    CFMutableArrayRef	mListenerRemotePorts;
    UInt32			mListenerSequenceNumber;
};

#endif // __MessagePortBroadcaster_h__
