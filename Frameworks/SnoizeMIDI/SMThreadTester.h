//
//  SMThreadTester.h
//  SnoizeMIDI
//
//  Created by Kurt Revis on Sun Dec 16 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMThreadTester : NSObject
{
    NSLock *recordsLock;
    NSMutableArray *records;
    UInt64 savedSleepTime;
    NSLock *dataCollectionLock;
}

- (void)dumpRecords;

@end
