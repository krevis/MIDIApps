//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SnoizeMIDI.h>
#import <SnoizeMIDISpy/SnoizeMIDISpy.h>


@interface SMMSpyingInputStream : SMInputStream
{
    MIDISpyClientRef spyClient;
    SMMessageParser *parser;
}


@end
