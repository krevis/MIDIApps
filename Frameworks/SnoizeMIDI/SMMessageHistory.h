#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>


@interface SMMessageHistory : OFObject <SMMessageDestination>
{
    NSMutableArray *savedMessages;
    NSLock *savedMessagesLock;
    unsigned int historySize;
}

+ (unsigned int)defaultHistorySize;

- (NSArray *)savedMessages;
    // Returns a snapshot of the current history.
    
- (void)clearSavedMessages;

- (unsigned int)historySize;
- (void)setHistorySize:(unsigned int)newHistorySize;

@end

// Notifications
extern NSString *SMMessageHistoryChangedNotification;

extern NSString *SMMessageHistoryWereMessagesAdded;
    // The notification's userInfo contains an NSNumber with a BOOL under this key, indicating if messages were added or not
