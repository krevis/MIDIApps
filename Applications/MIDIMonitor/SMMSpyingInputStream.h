//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SnoizeMIDI.h>
#import <SnoizeMIDISpy/SnoizeMIDISpy.h>


@interface SMMSpyingInputStream : SMInputStream
{
    MIDISpyClientRef spyClient;
    NSMapTable *endpointToParserMapTable;    SMSimpleInputStreamSource *inputStreamSource;
}

- (BOOL)isActive;
- (void)setIsActive:(BOOL)value;

@end
