//
//  SMMDisclosableView.h
//  MIDIMonitor
//
//  Created by krevis on Wed Oct 24 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/NSBox.h>
#import <AppKit/NSNibDeclarations.h>

@interface SMMDisclosableView : NSView
{
    BOOL isShown;
    double originalHeight;
    double hiddenHeight;
    NSArray *hiddenSubviews;
    NSView *nonretainedOriginalNextKeyView;
    NSView *nonretainedLastChildKeyView;
    NSSize sizeBeforeHidden;
}

- (BOOL)isShown;
- (void)setIsShown:(BOOL)value;

- (double)hiddenHeight;
- (void)setHiddenHeight:(double)value;

// Actions
- (IBAction)toggleDisclosure:(id)sender;
- (IBAction)hide:(id)sender;
- (IBAction)show:(id)sender;

@end

