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
    if (!(self = [super init]))
        return nil;
    
    [NSBundle loadNibNamed:@"DisclosableViewInspector" owner:self];
    return self;
}

- (void)revert:(id)sender
{
    [super revert:sender];
    [hiddenHeightField setFloatValue:[[self object] hiddenHeight]]; 
}

- (IBAction)setHiddenHeight:(id)sender
{
    [(SNDisclosableView *)[self object] setHiddenHeight:[sender floatValue]];
}

@end
