//
//  SMMDisclosableView.m
//  MIDIMonitor
//
//  Created by krevis on Wed Oct 24 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SMMDisclosableView.h"
#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>


@interface SMMDisclosableView (Private)

- (void)_changeWindowHeightBy:(double)amount;

@end


@implementation SMMDisclosableView

- (id)initWithFrame:(NSRect)frameRect;
{
    if (!(self = [super initWithFrame:frameRect]))
        return nil;

    isShown = YES;
    originalHeight = [self frame].size.height;
    hiddenHeight = 0;

    return self;
}

- (void)dealloc;
{
    [hiddenSubviews release];
    
    [super dealloc];
}

- (void)awakeFromNib;
{
    if ([[self superclass] instancesRespondToSelector:@selector(awakeFromNib)])
        [super awakeFromNib];
        
    isShown = YES;
    originalHeight = [self frame].size.height;
}

- (BOOL)acceptsFirstResponder
{
    return NO;
}

- (BOOL)isShown;
{
    return isShown;
}

- (void)setIsShown:(BOOL)value;
{
    if (isShown != value) {
        if (value)
            [self show:nil];
        else
            [self hide:nil];
    }
}

- (double)hiddenHeight;
{
    return hiddenHeight;
}

- (void)setHiddenHeight:(double)value;
{
    hiddenHeight = value;
}

//
// Actions
//

- (IBAction)toggleDisclosure:(id)sender;
{
    if (isShown)
        [self hide:sender];
    else
        [self show:sender];
}

- (IBAction)hide:(id)sender;
{
    NSView *keyLoopView;
    unsigned int subviewIndex;

    if (!isShown)
        return;

    OBASSERT(hiddenSubviews == nil);

    keyLoopView = [self nextKeyView];
    if ([keyLoopView isDescendantOf:self]) {
        // We need to remove our subviews (which will be hidden) from the key loop.
    
        // Remember our nextKeyView so we can restore it later.
        nonretainedOriginalNextKeyView = keyLoopView;

        // Find the last view in the key loop which is one of our descendants.
        nonretainedLastChildKeyView = keyLoopView;
        while ((keyLoopView = [nonretainedLastChildKeyView nextKeyView])) {
            if ([keyLoopView isDescendantOf:self])
                nonretainedLastChildKeyView = keyLoopView;
            else
                break;
        }
            
        // Set our nextKeyView to its nextKeyView, and set its nextKeyView to nil.
        // (If we don't do the last step, when we restore the key loop later, it will be missing views in the backwards direction.)
        [self setNextKeyView:keyLoopView];
        [nonretainedLastChildKeyView setNextKeyView:nil];
    } else {
        nonretainedOriginalNextKeyView = nil;
    }

    hiddenSubviews = [[NSArray alloc] initWithArray:[self subviews]];
    subviewIndex = [hiddenSubviews count];
    while (subviewIndex--)
        [[hiddenSubviews objectAtIndex:subviewIndex] removeFromSuperview];

    sizeBeforeHidden = [self frame].size;
    [self setFrameSize:NSMakeSize(sizeBeforeHidden.width, hiddenHeight)];

    [self _changeWindowHeightBy:-(originalHeight - hiddenHeight)];

    isShown = NO;
}

- (IBAction)show:(id)sender;
{
    unsigned int subviewIndex;

    if (isShown)
        return;

    [self _changeWindowHeightBy:(originalHeight - hiddenHeight)];

    [self setFrameSize:NSMakeSize([self frame].size.width, originalHeight)];

    subviewIndex = [hiddenSubviews count];
    while (subviewIndex--)
        [self addSubview:[hiddenSubviews objectAtIndex:subviewIndex]];

    [hiddenSubviews release];
    hiddenSubviews = nil;

    [self resizeSubviewsWithOldSize:sizeBeforeHidden];

    if (nonretainedOriginalNextKeyView) {
        // Restore the key loop to its old configuration.
        [nonretainedLastChildKeyView setNextKeyView:[self nextKeyView]];
        [self setNextKeyView:nonretainedOriginalNextKeyView];
    }

    isShown = YES;
}

@end


@implementation SMMDisclosableView (Private)

- (void)_changeWindowHeightBy:(double)amount;
{
    // This turns out to be more complicated than one might expect, because the way that the other views in the window should move is different than the normal case that the AppKit handles.
    // We want the other views in the window to stay the same size. If a view is above us, we want it to stay in the same position relative to the top of the window; likewise, if a view is below us, we want it to stay in the same position relative to the bottom of the window. However, views may have different autoresize masks configured.
    // So, we save the old autoresize masks for all of the window's content view's immediate subviews, and set them how we want them.
    // Then, we resize the window, and fix up the minimum and maximum sizes for the window.
    // Afterwards, we restore the autoresize masks.
    // (Also note that we do not want to modify our own autoresize mask.)

    NSWindow *window;
    NSView *contentView;
    NSArray *windowSubviews;
    unsigned int windowSubviewCount, windowSubviewIndex;
    NSMutableArray *savedAutoresizeMasks;
    NSRect newWindowFrame;
    NSSize newWindowMinOrMaxSize;

    window = [self window];
    contentView = [window contentView];

    windowSubviews = [contentView subviews];
    windowSubviewCount = [windowSubviews count];
    savedAutoresizeMasks = [NSMutableArray arrayWithCapacity:windowSubviewCount];
    
    for (windowSubviewIndex = 0; windowSubviewIndex < windowSubviewCount; windowSubviewIndex++) {
        NSView *windowSubview;
        unsigned int autoresizingMask;
        
        windowSubview = [windowSubviews objectAtIndex:windowSubviewIndex];
        autoresizingMask = [windowSubview autoresizingMask];
        [savedAutoresizeMasks addObject:[NSNumber numberWithUnsignedInt:autoresizingMask]];

        if (windowSubview == self)
            continue;

        // We never want to anything to change height.
        autoresizingMask &= ~NSViewHeightSizable;
        if (NSMaxY([windowSubview frame]) >= NSMaxY([self frame])) {
            // This subview is above us. Set it to be stuck to the top of the window.
            autoresizingMask &= ~NSViewMaxYMargin;
            autoresizingMask |= NSViewMinYMargin;
        } else {
            // This subview is below us. Set it to be stuck to the bottom of the window.
            autoresizingMask |= NSViewMaxYMargin;
            autoresizingMask &= ~NSViewMinYMargin;
        }
        [windowSubview setAutoresizingMask:autoresizingMask];
    }
    
    newWindowFrame = [window frame];
    newWindowFrame.origin.y -= amount;
    newWindowFrame.size.height += amount;
    if ([window isVisible])
        [window setFrame:newWindowFrame display:YES animate:YES];
    else
        [window setFrame:newWindowFrame display:NO];

    newWindowMinOrMaxSize = [window minSize];
    newWindowMinOrMaxSize.height += amount;
    [window setMinSize:newWindowMinOrMaxSize];

    newWindowMinOrMaxSize = [window maxSize];
    // If there is no max size set (height of 0), don't change it.
    if (newWindowMinOrMaxSize.height > 0) {
        newWindowMinOrMaxSize.height += amount;
        [window setMaxSize:newWindowMinOrMaxSize];
    }

    for (windowSubviewIndex = 0; windowSubviewIndex < windowSubviewCount; windowSubviewIndex++) {
        NSView *windowSubview;
        
        windowSubview = [windowSubviews objectAtIndex:windowSubviewIndex];
        if (windowSubview == self)
            continue;

        [windowSubview setAutoresizingMask:[[savedAutoresizeMasks objectAtIndex:windowSubviewIndex] unsignedIntValue]];
    }
}

@end
