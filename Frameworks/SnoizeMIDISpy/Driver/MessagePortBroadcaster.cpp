#include "MessagePortBroadcaster.h"

extern "C" {
    static CFDataRef registrationCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);
}

MessagePortBroadcaster::MessagePortBroadcaster(CFStringRef broadcasterName, MessagePortBroadcasterDelegate *delegate) :
    mDelegate(delegate),
    mBroadcasterName(NULL),
    mListenerRegistrationLocalPort(NULL),
    mListenerRegistrationRunLoopSource(NULL),
    mListenerRemotePorts(NULL),
    mListenerSequenceNumber(0)
{
    CFMessagePortContext messagePortContext = { 0, (void *)this, NULL, NULL, NULL };

    if (!broadcasterName)
        broadcasterName = CFSTR("Unknown Broadcaster");
    mBroadcasterName = CFStringCreateCopy(kCFAllocatorDefault, broadcasterName);
        
    // Create a local port for remote listeners to register with
    mListenerRegistrationLocalPort = CFMessagePortCreateLocal(kCFAllocatorDefault, mBroadcasterName, registrationCallBack, &messagePortContext, FALSE);

    // And add it to the current run loop
    mListenerRegistrationRunLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, mListenerRegistrationLocalPort, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), mListenerRegistrationRunLoopSource, kCFRunLoopDefaultMode);

    // Create an array to store remote ports in
    mListenerRemotePorts = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
}

MessagePortBroadcaster::~MessagePortBroadcaster()
{
    CFRelease(mListenerRemotePorts);    

    CFRunLoopSourceInvalidate(mListenerRegistrationRunLoopSource);
    CFRelease(mListenerRegistrationRunLoopSource);
    
    CFMessagePortInvalidate(mListenerRegistrationLocalPort);
    CFRelease(mListenerRegistrationLocalPort);

    CFRelease(mBroadcasterName);    
}

void MessagePortBroadcaster::Broadcast(CFDataRef dataToBroadcast)
{
    CFIndex listenerIndex;

    listenerIndex = CFArrayGetCount(mListenerRemotePorts);
    if (listenerIndex == 0)
        return;
    
    while (listenerIndex--) {
        CFMessagePortRef listenerPort;

        listenerPort = (CFMessagePortRef)CFArrayGetValueAtIndex(mListenerRemotePorts, listenerIndex);
        if (CFMessagePortIsValid(listenerPort)) {
            CFMessagePortSendRequest(listenerPort, 0, dataToBroadcast, 300, 0, NULL, NULL);
        } else {
            CFArrayRemoveValueAtIndex(mListenerRemotePorts, listenerIndex);
        }
    }

    if (mDelegate && CFArrayGetCount(mListenerRemotePorts) == 0)
        mDelegate->BroadcasterListenerCountChanged(this, false);
}

static CFDataRef registrationCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
    MessagePortBroadcaster *broadcaster = (MessagePortBroadcaster *)info;

    if (msgid == 0) {
        return broadcaster->NextSequenceNumber();
    } else if (msgid == 1) {
        broadcaster->AddListener(data);
        return NULL;
    } else {
        return NULL;
    }
}

CFDataRef	MessagePortBroadcaster::NextSequenceNumber()
{
    // Client is starting up; it wants to know what sequence number to use (so it can name its local port).
    // We give it that data in a reply.

    CFDataRef returnedData;

    mListenerSequenceNumber++;
    returnedData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&mListenerSequenceNumber, sizeof(mListenerSequenceNumber));

    return returnedData;
}

void	MessagePortBroadcaster::AddListener(CFDataRef listenerSequenceNumberData)
{
    // Client has created a local port on its side, and we need to create a remote port for it.
    // No reply is necessary.

    const UInt8 *dataBytes;
    UInt32 listenerSequenceNumber;
    CFStringRef listenerPortName;
    CFMessagePortRef remoteListenerPort;

    if (!listenerSequenceNumberData || CFDataGetLength(listenerSequenceNumberData) != sizeof(UInt32))
        return;

    dataBytes = CFDataGetBytePtr(listenerSequenceNumberData);
    if (!dataBytes)
        return;

    listenerSequenceNumber = *(const UInt32 *)dataBytes;
    listenerPortName = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@-%lu"), mBroadcasterName, listenerSequenceNumber);

    remoteListenerPort = CFMessagePortCreateRemote(kCFAllocatorDefault, listenerPortName);
    if (remoteListenerPort) {
        CFArrayAppendValue(mListenerRemotePorts, remoteListenerPort);
        CFRelease(remoteListenerPort);

        if (mDelegate && CFArrayGetCount(mListenerRemotePorts) == 1)
            mDelegate->BroadcasterListenerCountChanged(this, true);
    }

    CFRelease(listenerPortName);
}

bool	MessagePortBroadcaster::HasListeners()
{
    return (CFArrayGetCount(mListenerRemotePorts) > 0);
}
