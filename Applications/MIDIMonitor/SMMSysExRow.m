//
//  SMMSysExRow.m
//  MIDIMonitor
//
//  Created by krevis on Fri Oct 26 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMMSysExRow.h"
#import <Cocoa/Cocoa.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>


@implementation SMMSysExRow

NSString *SMMSysExBytesPerRowPreferenceKey = @"SMMSysExBytesPerRow";

static OFPreference *bytesPerRowPreference = nil;

static unsigned int bytesPerRow()
{
    if (!bytesPerRowPreference)
        bytesPerRowPreference = [[OFPreference preferenceForKey:SMMSysExBytesPerRowPreferenceKey] retain];
        
    return [bytesPerRowPreference integerValue];
}

+ (unsigned int)rowCountForMessage:(SMSystemExclusiveMessage *)aMessage;
{
    unsigned int dataLength, rowLength;
    
    dataLength = [aMessage otherDataLength];        
    rowLength = bytesPerRow();
    return (dataLength / rowLength) + ((dataLength % rowLength) ? 1 : 0);
}

+ (NSArray *)sysExRowsForMessage:(SMSystemExclusiveMessage *)aMessage;
{
    unsigned int rowIndex, rowCount;
    NSMutableArray *rows;
    
    rowCount = [self rowCountForMessage:aMessage];
    rows = [NSMutableArray arrayWithCapacity:rowCount];
    for (rowIndex = 0; rowIndex < rowCount; rowIndex++) {
        SMMSysExRow *newRow;
    
        newRow = [[self alloc] initWithMessage:aMessage rowIndex:rowIndex];
        [rows addObject:newRow];
        [newRow release];
    }
    
    return rows;
}

- (id)initWithMessage:(SMSystemExclusiveMessage *)aMessage rowIndex:(unsigned int)rowIndex
{
    if (!(self = [super init]))
        return nil;

    message = [aMessage retain];
    offset = rowIndex * bytesPerRow();

    return self;
}

- (void)dealloc
{
    [message release];

    [super dealloc];
}

- (NSString *)formattedOffset;
{
    return [SMMessage formatLength:offset];
}

- (NSString *)formattedData;
{
    NSData *data;
    unsigned int dataLength, rowLength;
    
    data = [message otherData];
    dataLength = [data length];

    if (offset > dataLength)
        return @"";

    rowLength = MIN(dataLength - offset, bytesPerRow());
    return [SMMessage formatDataBytes:([data bytes] + offset) length:rowLength];
}

@end
