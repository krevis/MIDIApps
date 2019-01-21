//
//  SMShowControlUtilities.m
//  SnoizeMIDI
//
//  Created by Hugo Trippaers on 22/12/2018.
//

#import <Foundation/Foundation.h>

#import "SMShowControlUtilities.h"

#define BIT(n)                  ( 1<<(n) )
#define BIT_MASK(len)           ( BIT(len)-1 )
#define BITFIELD_MASK(start, len)     ( BIT_MASK(len)<<(start) )
#define BITFIELD_GET(y, start, len)   ( ((y)>>(start)) & BIT_MASK(len) )

SMTimecode parseTimecodeData(NSData *timecodeData) {
    SMTimecode timecode;
    const Byte *byte = timecodeData.bytes;
    // Hours and type: 0 tt hhhhh
    timecode.timecodeType = BITFIELD_GET(*byte, 5, 2);
    timecode.hours = BITFIELD_GET(*byte++, 0, 5);
    
    // Minutes and color frame bit: 0 c mmmmmm
    timecode.colorFrameBit = BITFIELD_GET(*byte, 6, 1);
    timecode.minutes = BITFIELD_GET(*byte++, 0, 5);
    
    // Seconds: 0 k ssssss
    timecode.seconds = BITFIELD_GET(*byte++, 0, 5);
    
    // Frames, byte 5 ident and sign: 0 g i fffff
    timecode.sign = BITFIELD_GET(*byte, 6, 1);
    timecode.form = BITFIELD_GET(*byte, 5, 1);
    timecode.frames = BITFIELD_GET(*byte++, 0, 5);
    
    if (timecode.form) {
        // code status bit map:0 e v d xxxx
        timecode.statusEstimatedCodeFlag = BITFIELD_GET(*byte, 6, 1);
        timecode.statusInvalidCode = BITFIELD_GET(*byte, 5, 1);
        timecode.statusVideoFieldIndentification = BITFIELD_GET(*byte, 4, 1);
    } else {
        // fractional frames: 0 bbbbbbb
        timecode.subframes = BITFIELD_GET(*byte, 0, 7);
    }
    
    return timecode;
}

NSArray *parseCueItemsData(NSData *cueItemsData) {
    NSString *cueItemString = [[NSString alloc] initWithData:cueItemsData encoding:NSASCIIStringEncoding];
    return cueItemString.length > 0 ? [cueItemString componentsSeparatedByString:@"\0"] : @[];
}
