/*
 Copyright (c) 2002-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

NS_ASSUME_NONNULL_BEGIN

static __inline__ NSBundle *SMBundleForObject(id object) {
    return [NSBundle bundleForClass:[object class]];
}

// TODO Make an internal SMBundle() that returns the SnoizeMIDI bundle (and looks it up only once)

extern void SMRequestConcreteImplementation(id self, SEL _cmd);
extern void SMRejectUnusedImplementation(id self, SEL _cmd);

#if DEBUG
#define SMAssert(expression)	if (!(expression)) SMAssertionFailed(#expression, __FILE__, __LINE__)
extern void SMAssertionFailed(const char *expression, const char *file, unsigned int line);
#else
#define SMAssert(expression)
#endif

// Work around a bug in the declaration of MIDIPacketListAdd(). The return value should be _Nullable,
// so Swift code can compare it to nil.
// This function just calls MIDIPacketListAdd() and does nothing extra.
extern MIDIPacket * _Nullable SMWorkaroundMIDIPacketListAdd(MIDIPacketList *pktlist, ByteCount listSize, MIDIPacket *curPacket, MIDITimeStamp time, ByteCount nData, const Byte *data);

// Return the size of the packet list. Include only the actual valid data in the packets,
// ignoring any extra space that may appear to be in the MIDIPacket structure because of its
// fixed size data array.
// In Swift, use MIDIPacketList.sizeInBytes() instead, when it's available.
extern NSInteger SMPacketListSize(const MIDIPacketList *packetList);

// Iterate through the packets in the given packet list, calling the given block for each packet.
// In Swift, use packetList.unsafeSequence() instead, when it's available.
extern void SMPacketListApply(const MIDIPacketList *packetList, void (NS_NOESCAPE ^block)(const MIDIPacket *packet));

NS_ASSUME_NONNULL_END
