//
//  SSEAppController.h
//  MIDIMonitor
//
//  Created by krevis on Sun Apr 15 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>


@interface SSEAppController : NSObject
{
}

- (IBAction)showPreferences:(id)sender;
- (IBAction)showAboutBox:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)showMainWindow:(id)sender;

@end
