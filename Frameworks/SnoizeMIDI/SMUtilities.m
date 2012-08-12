/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SMUtilities.h"
#import <AvailabilityMacros.h>
#import <objc/runtime.h>
#import <CoreMIDI/CoreMIDI.h>


void SMRequestConcreteImplementation(id self, SEL _cmd)
{
    NSString *message = [NSString stringWithFormat:@"Object %@ of class %@ has no concrete implementation of selector %@", self, NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    NSAssert(NO, message);
}

void SMRejectUnusedImplementation(id self, SEL _cmd)
{
    NSString *message = [NSString stringWithFormat:@"Object %@ of class %@ was sent selector %@ which should be not be used", self, NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    NSAssert(NO, message);
}

BOOL SMClassIsSubclassOfClass(Class class, Class potentialSuperclass)
{
    // Like +[NSObject isSubclassOfClass:], but works correctly for classes which are NOT based on NSObject

    while (class) {
        if (class == potentialSuperclass)
            return YES;
        class = class_getSuperclass(class);
    }

    return NO;
}

#if DEBUG
extern void SMAssertionFailed(const char *expression, const char *file, unsigned int line)
{
    NSLog(@"SnoizeMIDI: Assertion failed: condition %s, file %s, line %u", expression, file, line);
}
#endif

UInt32 SMPacketListSize(const MIDIPacketList *packetList)
{
    const MIDIPacket *packet;
    UInt32 i;
    UInt32 size;

    // Find the size of the whole packet list
    size = offsetof(MIDIPacketList, packet);
    packet = &packetList->packet[0];
    for (i = 0; i < packetList->numPackets; i++) {
        size += offsetof(MIDIPacket, data) + packet->length;
        packet = MIDIPacketNext(packet);
    }

    return size;    
}
