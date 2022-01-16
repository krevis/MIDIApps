/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

#import <SnoizeMIDI/SMMIDIUtilities.h>

MIDIPacket * _Nullable SMWorkaroundMIDIPacketListAdd(MIDIPacketList *pktlist, ByteCount listSize, MIDIPacket *curPacket, MIDITimeStamp time, ByteCount nData, const Byte *data)
{
    // MIDIPacketListAdd isn't declared as returning a _Nullable pointer, but it should be
    return MIDIPacketListAdd(pktlist, listSize, curPacket, time, nData, data);
}

NSInteger SMPacketListSize(const MIDIPacketList * _Nonnull packetList)
{
    // Implemented in C, since trying to do this in Swift is maddening
    // and pointless -- Swift MIDIPacketList.sizeInBytes() works fine,
    // when it's available.

    // Iterate just past the last packet in the list, then subtract to return the total size.
    // (Arguably, we don't need to include the padding at the end of the last packet, but
    // this way matches the behavior of MIDIPacketList.sizeInBytes() which does.)

    const MIDIPacket *packet = &packetList->packet[0];
    for (UInt32 i = 0; i < packetList->numPackets; i++) {
        packet = MIDIPacketNext(packet);
    }
    NSInteger size = (intptr_t)(packet) - (intptr_t)packetList;
    return size;
}

void SMPacketListApply(const MIDIPacketList *packetList, void (NS_NOESCAPE ^block)(const MIDIPacket *packet))
{
    // This is similarly maddening to implement in Swift. If you have an UnsafePointer<MIDIPacketList>
    // which is based on data that is exactly sized to fit the packet list, calling `pointee`
    // will crash (at least, under ASAN). Just do it in C.
    //
    // For reference, here's a similar case, with a much more expensive workaround that's all Swift:
    // https://stackoverflow.com/questions/68229346/crash-with-midipacketnext

    if (packetList->numPackets == 0) {
        return;
    }
    const MIDIPacket *packet = &packetList->packet[0];
    for (UInt32 i = 0; i < packetList->numPackets; i++) {
        block(packet);
        packet = MIDIPacketNext(packet);
    }
}
