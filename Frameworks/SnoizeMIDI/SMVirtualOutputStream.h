//
//  SMVirtualOutputStream.h
//  SnoizeMIDI
//
//  Created by krevis on Tue Dec 04 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <SnoizeMIDI/SMOutputStream.h>
#import <CoreMIDI/MIDIServices.h>

@class SMSourceEndpoint;

@interface SMVirtualOutputStream : SMOutputStream
{
    SMSourceEndpoint *endpoint;
}

- (id)initWithName:(NSString *)name uniqueID:(SInt32)uniqueID;

- (SMSourceEndpoint *)endpoint;

@end
