#import "SMHostTime.h"
#include <mach/mach_time.h>

static int isInited = 0;
static Float64 nanoRatio;

static void InitHostTime()
{
    struct mach_timebase_info info;

    mach_timebase_info(&info);
    nanoRatio = (double)info.numer / (double)info.denom;

    isInited = 1;
}

MIDITimeStamp SMGetCurrentHostTime()
{
    return mach_absolute_time();
}

UInt64 SMConvertHostTimeToNanos(MIDITimeStamp hostTime)
{
    if (!isInited)
        InitHostTime();
    return (UInt64)(hostTime * nanoRatio);
}

MIDITimeStamp SMConvertNanosToHostTime(UInt64 nanos)
{
    if (!isInited)
        InitHostTime();
    return (UInt64)(nanos / nanoRatio);
}
