//
//  SNDisclosableViewInspector.h
//  DisclosableViewPalette
//
//  Created by Kurt Revis on Fri Jul 12 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <InterfaceBuilder/InterfaceBuilder.h>

@interface SNDisclosableViewInspector : IBInspector
{
    IBOutlet NSTextField *hiddenHeightField;
}

- (IBAction)setHiddenHeight:(id)sender;

@end
