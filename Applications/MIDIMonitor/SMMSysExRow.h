//
//  SMMSysExRow.h
//  MIDIMonitor
//
//  Created by krevis on Fri Oct 26 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>

@class NSArray;
@class SMSystemExclusiveMessage;

@interface SMMSysExRow : OFObject
{
    SMSystemExclusiveMessage *message;
    unsigned int offset;
}

+ (unsigned int)rowCountForMessage:(SMSystemExclusiveMessage *)aMessage;
+ (NSArray *)sysExRowsForMessage:(SMSystemExclusiveMessage *)aMessage;

- (id)initWithMessage:(SMSystemExclusiveMessage *)aMessage rowIndex:(unsigned int)rowIndex;

- (NSString *)formattedOffset;
- (NSString *)formattedData;

@end

// Preference keys
extern NSString *SMMSysExBytesPerRowPreferenceKey;
