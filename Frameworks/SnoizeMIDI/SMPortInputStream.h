//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SMInputStream.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class SMSourceEndpoint;


@interface SMPortInputStream : SMInputStream
{
    MIDIPortRef inputPort;
    NSMutableSet *endpoints;
    NSMapTable *parsersForEndpoints;
}

- (NSSet *)endpoints;
- (void)addEndpoint:(SMSourceEndpoint *)endpoint;
- (void)removeEndpoint:(SMSourceEndpoint *)endpoint;
- (void)setEndpoints:(NSSet *)newEndpoints;

@end
