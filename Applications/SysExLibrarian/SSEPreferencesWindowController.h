//
//  SSEPreferencesWindowController.h
//  MIDIMonitor
//
//  Created by krevis on Sun Sep 23 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <AppKit/NSWindowController.h>
#import <AppKit/NSNibDeclarations.h>

@class NSButton, NSMatrix, NSPopUpButton;	// AppKit
@class OFPreference;		// OmniFoundation

@interface SSEPreferencesWindowController : NSWindowController
{
// TODO  for example:
//    IBOutlet NSMatrix *timeFormatMatrix;

//    OFPreference *timeFormatPreference;
}

+ (SSEPreferencesWindowController *)preferencesWindowController;

- (id)init;

//- (IBAction)changeTimeFormat:(id)sender;

@end
