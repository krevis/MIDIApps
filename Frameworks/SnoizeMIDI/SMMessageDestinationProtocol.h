//
//  SMMessageDestinationProtocol.h
//  SnoizeMIDI.framework
//
//  Created by krevis on Sat Sep 08 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <Foundation/NSObject.h>

@class NSArray;


@protocol SMMessageDestination <NSObject>

- (void)takeMIDIMessages:(NSArray *)messages;

@end

