//
//  SMScheduler.h
//  SnoizeMIDI
//
//  Created by krevis on Sun Dec 09 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <OmniFoundation/OFDedicatedThreadScheduler.h>


@interface SMScheduler : OFDedicatedThreadScheduler
{
}

+ (SMScheduler *)midiScheduler;

@end
