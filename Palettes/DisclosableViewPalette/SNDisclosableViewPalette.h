//
//  SNDisclosableViewPalette.h
//  DisclosableViewPalette
//
//  Created by Kurt Revis on Fri Jul 12 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <InterfaceBuilder/InterfaceBuilder.h>
#import <DisclosableView/SNDisclosableView.h>


@interface SNDisclosableViewPalette : IBPalette
{
}
@end


@interface SNDisclosableView (IBPaletteInspector)
- (NSString *)inspectorClassName;
@end
