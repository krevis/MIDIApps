//
//  SNDisclosableView-Additions.m
//  DisclosableViewPalette
//
//  Created by Kurt Revis on Fri Jul 12 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SNDisclosableView-Additions.h"
#import <InterfaceBuilder/IBViewAdditions.h>
#import <InterfaceBuilder/IBObjectAdditions.h>


@interface NSView (UndocumentedIBAdditions)

- (BOOL)editorHandlesCaches;

@end


@implementation SNDisclosableView (IBPaletteAdditions)

- (BOOL)ibIsContainer
{
    return YES;
}

- (BOOL)ibSupportsInsideOutSelection;
{
    return YES;
}

- (BOOL)ibShouldShowContainerGuides;
{
    return YES;
}

- (BOOL)ibDrawFrameWhileResizing;
{
    return YES;
}

- (id)ibNearestTargetForDrag;
{
    // This is the key to allowing views to be dragged into this view.
    return self;
}

- (BOOL)canEditSelf;
{
    // We need this in order to allow our subviews to be moved around and edited.
    return YES;
}

/*
- (BOOL)editorHandlesCaches
{
    return YES;
    // The default NSView implementation returns NO, which seems wrong. If we leave it as NO,
    // when editing in IB, our subviews will not get erased when they are moved around.
}
*/

/*
 - (void)ibPreCache;
 - (void)ibPostCache;
 - (void)ibPreCacheSubviews;
 - (void)ibPostCacheSubviews;
*/ 

/*
- (NSString*)ibWidgetType;
{
    NSString *value = [super ibWidgetType];
    NSLog(@"ibWidgetType: super: %@", value);
    {
        id object = [[[NSClassFromString(@"NSCustomView") alloc] init] autorelease];
        NSString *value2 = [object ibWidgetType];
        NSLog(@"ibWidgetType: NSCustomView (%@): %@", object, value2);
    }
    {
        id object = [[[NSClassFromString(@"NSBox") alloc] init] autorelease];
        NSString *value2 = [object ibWidgetType];
        NSLog(@"ibWidgetType: NSBox (%@): %@", object, value2);
    }
    return @"Box";
//    return value;
}
*/
/*
- (NSString *)editorClassName;
{
    NSString *value = [super editorClassName];
    NSLog(@"editorClassName is %@", value);

    {
        id object = [[NSClassFromString(@"NSCustomView") alloc] init];
        value = [object editorClassName];
        NSLog(@"object (%@) editorClassName = %@", object, value);
    }
    
    return value;
}
*/

- (void)editSelf:(NSEvent *)theEvent in:(NSView<IBEditors>*)viewEditor;
{
    NSLog(@"editing self; view editor is %@", viewEditor);
    [super editSelf:theEvent in:viewEditor];
}

@end
