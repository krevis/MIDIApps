//
//  NSPopUpButton-Extensions.h
//  MIDIMonitor
//
//  Created by krevis on Wed Oct 31 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/NSPopUpButton.h>

@interface NSPopUpButton (SMMExtensions)

- (void)addItemWithTitle:(NSString *)title representedObject:(id)object;
- (void)addSeparatorItem;

- (void)selectItemWithTag:(int)tag;


@end
