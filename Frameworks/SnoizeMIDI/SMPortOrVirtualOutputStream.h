//
//  SMPortOrVirtualOutputStream.h
//  SnoizeMIDI
//
//  Created by krevis on Fri Dec 07 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <SnoizeMIDI/SMPortOrVirtualStream.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@interface SMPortOrVirtualOutputStream : SMPortOrVirtualStream <SMMessageDestination>
{
}

@end
