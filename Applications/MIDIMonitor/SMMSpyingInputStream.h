//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SnoizeMIDI.h>
#import <SnoizeMIDISpy/SnoizeMIDISpy.h>


@interface SMMSpyingInputStream : SMInputStream
{
    MIDISpyClientRef spyClient;
    MIDISpyPortRef spyPort;
    NSMutableSet *endpoints;
    NSMapTable *parsersForEndpoints;
}

- (id)initWithMIDISpyClient:(MIDISpyClientRef)midiSpyClient;

- (NSSet *)endpoints;
- (void)addEndpoint:(SMDestinationEndpoint *)endpoint;
- (void)removeEndpoint:(SMDestinationEndpoint *)endpoint;
- (void)setEndpoints:(NSSet *)newEndpoints;

@end
