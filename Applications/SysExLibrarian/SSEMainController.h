//
//  SSEMainController.h
//  SysExLibrarian
//
//  Created by Kurt Revis on Mon Dec 31 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

@class NSArray, NSDictionary;
@class SMPortOrVirtualInputStream, SMPortOrVirtualOutputStream;
@class SSEMainWindowController;

@interface SSEMainController : NSObject <SMMessageDestination>
{
    IBOutlet SSEMainWindowController *windowController;

    // MIDI processing
    SMPortOrVirtualInputStream *inputStream;
    SMPortOrVirtualOutputStream *outputStream;
    
    // Transient data
    BOOL listenToMIDISetupChanges;
    unsigned int sysExBytesRead;    
}

- (NSArray *)sourceDescriptions;
- (NSDictionary *)sourceDescription;
- (void)setSourceDescription:(NSDictionary *)sourceDescription;

- (NSArray *)destinationDescriptions;
- (NSDictionary *)destinationDescription;
- (void)setDestinationDescription:(NSDictionary *)destinationDescription;

@end
