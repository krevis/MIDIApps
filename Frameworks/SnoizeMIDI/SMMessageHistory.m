//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMMessageHistory.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface SMMessageHistory (Private)

- (void)limitSavedMessages;
- (void)historyHasChangedWithNewMessages:(BOOL)wereNewMessages;

@end


@implementation SMMessageHistory

NSString *SMMessageHistoryChangedNotification = @"SMMessageHistoryChangedNotification";
NSString *SMMessageHistoryWereMessagesAdded = @"SMMessageHistoryWereMessagesAdded";


+ (unsigned int)defaultHistorySize;
{
    return 1000;
}


- (id)init;
{
    if (!(self = [super init]))
        return nil;

    savedMessages = [[NSMutableArray alloc] init];
    savedMessagesLock = [[NSLock alloc] init];
    historySize = [[self class] defaultHistorySize];

    return self;
}

- (void)dealloc;
{
    [savedMessages release];
    savedMessages = nil;
    [savedMessagesLock release];
    savedMessagesLock = nil;
    
    [super dealloc];
}

- (NSArray *)savedMessages;
{
    NSArray *messages;

    [savedMessagesLock lock];
    messages = [NSArray arrayWithArray:savedMessages];
    [savedMessagesLock unlock];
    
    return messages;
}

- (void)clearSavedMessages;
{
    BOOL wereMessages = NO;

    [savedMessagesLock lock];
    if ([savedMessages count] > 0) {
        wereMessages = YES;
        [savedMessages removeAllObjects];
    }
    [savedMessagesLock unlock];
    
    if (wereMessages)
        [self historyHasChangedWithNewMessages:NO];
}

- (unsigned int)historySize;
{
    return historySize;
}

- (void)setHistorySize:(unsigned int)newHistorySize;
{
    unsigned int oldMessageCount, newMessageCount;

    [savedMessagesLock lock];

    historySize = newHistorySize;
    
    oldMessageCount = [savedMessages count];
    [self limitSavedMessages];
    newMessageCount = [savedMessages count];

    [savedMessagesLock unlock];

    if (oldMessageCount != newMessageCount)
        [self historyHasChangedWithNewMessages:NO];
}

- (void)takeMIDIMessages:(NSArray *)messages;
{
    [savedMessagesLock lock];
    [savedMessages addObjectsFromArray:messages];
    [self limitSavedMessages];
    [savedMessagesLock unlock];
    
    [self historyHasChangedWithNewMessages:YES];
}

@end


@implementation SMMessageHistory (Private)

- (void)limitSavedMessages;
{
    // NOTE We assume that this thread has taken the savedMessagesLock
    unsigned int messageCount;

    messageCount = [savedMessages count];
    if (messageCount > historySize) {
        NSRange deleteRange;
        
        deleteRange = NSMakeRange(0, messageCount - historySize);
        [savedMessages removeObjectsInRange:deleteRange];
    }
}

- (void)historyHasChangedWithNewMessages:(BOOL)wereNewMessages;
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:wereNewMessages] forKey:SMMessageHistoryWereMessagesAdded];

    [[NSNotificationCenter defaultCenter] postNotificationName:SMMessageHistoryChangedNotification object:self userInfo:userInfo];
}

@end
