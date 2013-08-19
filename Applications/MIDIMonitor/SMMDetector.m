//
//  SMMDetector.m
//  MIDIMonitor
//
//  Created by Kurt Revis on 8/18/13.
//
//

#import "SMMDetector.h"
#import <SnoizeMIDI/SnoizeMIDI.h>

@implementation SMMDetector

- (void)takeMIDIMessages:(NSArray *)messages
{
    for (SMMessage* message in messages) {
        // Check each incoming MIDI message and see if it's the MMC message we're looking for.
        
        // Based on http://home.roadrunner.com/~jgglatt/tech/mmc.htm :
        // MMC commands are sysex..
        if ([message isKindOfClass:[SMSystemExclusiveMessage class]]) {
            SMSystemExclusiveMessage* sysexMessage = (SMSystemExclusiveMessage *)message;
            // which have 4 bytes of data (not including the 0xF0 start byte and 0xF7 end byte)...
            NSData* sysexData = [sysexMessage data];
            if (sysexData.length == 4) {
                // and are of the form 0x7F <deviceID> 0x06 <command>
                const UInt8* sysexBytes = (const UInt8*)[sysexData bytes];
                if (sysexBytes[0] == 0x7F && sysexBytes[2] == 0x06) {
                    // 3rd byte is the command
                    if (sysexBytes[3] == 0x02) {  // Play
                        // best to do it in an async block, so you don't slow down MIDI processing
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // send your AppleScript here
                        });
                    }
                }
            }
        }
    }
}

@end
