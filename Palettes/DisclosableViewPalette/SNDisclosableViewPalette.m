//
//  SNDisclosableViewPalette.m
//  DisclosableViewPalette
//
//  Created by Kurt Revis on Fri Jul 12 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SNDisclosableViewPalette.h"


@implementation SNDisclosableViewPalette

- (void)finishInstantiate
{
    /* `finishInstantiate' can be used to associate non-view objects with
     * a view in the palette's nib.  For example:
     *   [self associateObject:aNonUIObject ofType:IBObjectPboardType
     *                withView:aView];
     */
}

@end


@implementation SNDisclosableView (IBPaletteInspector)

- (NSString *)inspectorClassName
{
    return @"SNDisclosableViewInspector";
}

@end
