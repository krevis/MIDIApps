#if !defined(__SNOIZE_MIDISPYSHARED__)
#define __SNOIZE_MIDISPYSHARED__ 1


//
// Constants which are shared between the driver and the client framework
//

// IDs of messages sent from client to driver via CFMessagePort
enum {
    kSpyingMIDIDriverGetNextListenerIdentifierMessageID = 0,
    kSpyingMIDIDriverAddListenerMessageID = 1,
    kSpyingMIDIDriverConnectDestinationMessageID = 2,
    kSpyingMIDIDriverDisconnectDestinationMessageID = 3
};



#endif /* ! __SNOIZE_MIDISPYSHARED__ */
