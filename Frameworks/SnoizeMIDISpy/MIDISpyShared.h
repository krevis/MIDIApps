//
// Constants which are shared between the driver and the client framework
//

// IDs of messages sent from client to driver via CFMessagePort
enum {
    kSpyingMIDIDriverNextSequenceNumberMessageID = 0,
    kSpyingMIDIDriverAddListenerMessageID = 1,
    kSpyingMIDIDriverConnectDestinationMessageID = 2,
    kSpyingMIDIDriverDisconnectDestinationMessageID = 3
};
