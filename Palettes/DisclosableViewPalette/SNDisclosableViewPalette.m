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
    // Send awakeFromNib to the objects in the palette.
    // (Why doesn't IB do this by default?)
    // SNDisclosureButton needs this to get set up properly.

    NSArray *objects;
    unsigned int objectIndex;

    objects = [[self paletteDocument] objects];
    objectIndex = [objects count];
    while (objectIndex--) {
        id object = [objects objectAtIndex:objectIndex];
        if ([object respondsToSelector:@selector(awakeFromNib)])
            [object awakeFromNib];
    }    
}

@end
