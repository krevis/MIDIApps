//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol SMMessageDestination <NSObject>

- (void)takeMIDIMessages:(NSArray *)messages;

@end
