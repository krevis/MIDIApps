#include <CoreMIDI/CoreMIDI.h>

// These are our own versions of the CoreAudio HostTime functions:
// AudioGetCurrentHostTime()
// AudioConvertHostTimeToNanos()
// AudioConvertNanosToHostTime()
//
// We use these instead of CoreAudio's versions so we don't have to link against CoreAudio.

MIDITimeStamp SMGetCurrentHostTime();
UInt64 SMConvertHostTimeToNanos(MIDITimeStamp hostTime);
MIDITimeStamp SMConvertNanosToHostTime(UInt64 nanos);
