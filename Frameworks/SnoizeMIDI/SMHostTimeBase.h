/*
 Copyright (c) 2022, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

#import <CoreFoundation/CoreFoundation.h>

// These handy CoreAudio functions are present on macOS but not other platforms,
// for no apparent reason:
//     AudioGetCurrentHostTime()
//     AudioConvertHostTimeToNanos()
//     AudioConvertNanosToHostTime()
//
// They have obvious implementations, which Apple even publishes in sample code:
//     https://developer.apple.com/library/archive/samplecode/CoreAudioUtilityClasses/Introduction/Intro.html
// in the class CAHostTimeBase.
//
// So we cover the CoreAudio functions with our own, which work on non-macOS.
// The only reason this is C code is because it's extracted from the C++ sample code,
// and it wasn't worthwhile to take the risk of translating to Swift.

extern UInt64 SMGetCurrentHostTime(void);
extern UInt64 SMConvertHostTimeToNanos(UInt64 hostTime);
extern UInt64 SMConvertNanosToHostTime(UInt64 nanos);
