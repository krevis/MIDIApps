//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <SnoizeMIDI/SMOutputStream.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@class SMSourceEndpoint;


@interface SMVirtualOutputStream : SMOutputStream
{
    SMSourceEndpoint *endpoint;
}

- (id)initWithName:(NSString *)name uniqueID:(MIDIUniqueID)uniqueID;

- (SMSourceEndpoint *)endpoint;

@end
