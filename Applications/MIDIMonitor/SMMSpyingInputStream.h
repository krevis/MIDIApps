//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SnoizeMIDI.h>
#import <SnoizeMIDISpy/SnoizeMIDISpy.h>


@interface SMMSpyingInputStream : SMInputStream
{
    MIDISpyClientRef spyClient;
    MIDISpyPortRef spyPort;
    NSMutableArray *endpoints;
    NSMapTable *parsersForEndpoints;
}

- (NSArray *)endpoints;
- (void)addEndpoint:(SMDestinationEndpoint *)endpoint;
- (void)removeEndpoint:(SMDestinationEndpoint *)endpoint;
- (void)setEndpoints:(NSArray *)newEndpoints;

@end
