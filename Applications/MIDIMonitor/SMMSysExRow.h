#import <Cocoa/Cocoa.h>
#import <OmniFoundation/OFObject.h>

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
