/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

NS_ASSUME_NONNULL_BEGIN

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
