/*
 Copyright (c) 2022, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

#import "SMHostTimeUtilities.h"

#if TARGET_OS_OSX

#import <CoreAudio/CoreAudio.h>

#elif TARGET_OS_IPHONE

#import <mach/mach_time.h>
#import <pthread.h>

static pthread_once_t sIsInited;

static UInt32 sToNanosNumerator;
static UInt32 sToNanosDenominator;

static void Initialize(void) {
    struct mach_timebase_info theTimeBaseInfo;
    mach_timebase_info(&theTimeBaseInfo);

    sToNanosNumerator = theTimeBaseInfo.numer;
    sToNanosDenominator = theTimeBaseInfo.denom;
}

static UInt64 MultiplyByRatio(UInt64 inMuliplicand, UInt32 inNumerator, UInt32 inDenominator) {
    __uint128_t theAnswer = inMuliplicand;
    if (inNumerator != inDenominator) {
        theAnswer *= inNumerator;
        theAnswer /= inDenominator;
    }
    return (UInt64)theAnswer;
}

#endif  // TARGET_OS_IPHONE


UInt64 SMGetCurrentHostTime(void) {
#if TARGET_OS_OSX
    return AudioGetCurrentHostTime();
#elif TARGET_OS_IPHONE
    return mach_absolute_time();
#else
#error Unsupported platform
#endif
}

UInt64 SMConvertHostTimeToNanos(UInt64 hostTime) {
#if TARGET_OS_OSX
    return AudioConvertHostTimeToNanos(hostTime);
#elif TARGET_OS_IPHONE
    pthread_once(&sIsInited, Initialize);
    return MultiplyByRatio(hostTime, sToNanosNumerator, sToNanosDenominator);
#else
#error Unsupported platform
#endif
}

UInt64 SMConvertNanosToHostTime(UInt64 nanos) {
#if TARGET_OS_OSX
    return AudioConvertNanosToHostTime(nanos);
#elif TARGET_OS_IPHONE
    pthread_once(&sIsInited, Initialize);
    return MultiplyByRatio(nanos, sToNanosDenominator, sToNanosNumerator);
#else
#error Unsupported platform
#endif
}
