/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

    // Find the last packet in the packet list
    if (packetList->numPackets == 0) {
        return 0;
    }
    const MIDIPacket *packet = &packetList->packet[0];
    for (UInt32 i = 0; i < packetList->numPackets - 1; i++) {
        packet = MIDIPacketNext(packet);
    }
    NSInteger size = (intptr_t)(&packet->data[packet->length]) - (intptr_t)packetList;
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
