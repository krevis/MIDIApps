//
//  SNDisclosableViewInspector.m
//  DisclosableViewPalette
//
//  Created by Kurt Revis on Fri Jul 12 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SNDisclosableViewInspector.h"
#import <DisclosableView/SNDisclosableView.h>


@implementation SNDisclosableViewInspector

- (id)init
{
    self = [super init];
    [NSBundle loadNibNamed:@"DisclosableViewInspector" owner:self];
    return self;
}

- (void)ok:(id)sender
{
    /* Your code Here */
    [super ok:sender];
}

- (void)revert:(id)sender
{
    /* Your code Here */
    [super revert:sender];
}

- (IBAction)beep:(id)sender
{
    NSBeep();
}

@end
