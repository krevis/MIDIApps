//
//  SSEMainWindowController.h
//  SysExLibrarian
//
//  Created by Kurt Revis on Mon Dec 31 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/NSWindowController.h>
#import <AppKit/NSNibDeclarations.h>

@class NSPopUpButton;
@class SSEMainController;

@interface SSEMainWindowController : NSWindowController
{
    IBOutlet SSEMainController *mainController;

    IBOutlet NSPopUpButton *sourcePopUpButton;

}

+ (SSEMainWindowController *)mainWindowController;

// Actions

- (IBAction)selectSource:(id)sender;

// Other API

- (void)synchronizeInterface;
    // Calls each of the following
- (void)synchronizeSources;

@end
