#import "SNDisclosableView.h"

#import <Cocoa/Cocoa.h>


@interface SNDisclosableView (Private)

- (void)changeWindowHeightBy:(float)amount;

@end


@implementation SNDisclosableView

const float kDefaultHiddenHeight = 0.0;


- (id)initWithFrame:(NSRect)frameRect;
{
    if (!(self = [super initWithFrame:frameRect]))
        return nil;

    isShown = YES;
    originalHeight = [self frame].size.height;
    hiddenHeight = kDefaultHiddenHeight;

    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    if (!(self = [super initWithCoder:aDecoder]))
        return nil;

    isShown = YES;
    originalHeight = [self frame].size.height;
    hiddenHeight = kDefaultHiddenHeight;
    [aDecoder decodeValueOfObjCType:@encode(typeof(hiddenHeight)) at:&hiddenHeight];
    
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

    if ([self autoresizingMask] & NSViewHeightSizable)
        NSLog(@"Warning: SNDisclosableView: You probably don't want this view to be resizeable vertically. I suggest turning that off in the inspector in IB.");
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValueOfObjCType:@encode(typeof(hiddenHeight)) at:&hiddenHeight];
}

- (BOOL)acceptsFirstResponder
{
    return NO;
}

//
// New methods
//

- (BOOL)isShown;
{
    return isShown;
}

- (void)setIsShown:(BOOL)value;
{
    if (value)
        [self show:nil];
    else
        [self hide:nil];
}

- (float)hiddenHeight;
{
    return hiddenHeight;
}

- (void)setHiddenHeight:(float)value;
{
    hiddenHeight = value;
}

//
// Actions
//

- (IBAction)toggleDisclosure:(id)sender;
{
    [self setIsShown:!isShown];
}

- (IBAction)hide:(id)sender;
{
    NSView *keyLoopView;
    unsigned int subviewIndex;

    if (!isShown)
        return;

    NSAssert(hiddenSubviews == nil, @"-[SNDisclosableView hide]: should have no hidden subviews yet");

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

    [self changeWindowHeightBy:-(originalHeight - hiddenHeight)];

    [self setNeedsDisplay:YES];

    isShown = NO;
}

- (IBAction)show:(id)sender;
{
    unsigned int subviewIndex;

    if (isShown)
        return;

    [self changeWindowHeightBy:(originalHeight - hiddenHeight)];

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

    [self setNeedsDisplay:YES];
}

@end


@implementation SNDisclosableView (Private)

- (void)changeWindowHeightBy:(float)amount;
{
    // This turns out to be more complicated than one might expect, because the way that the other views in the window should move is different than the normal case that the AppKit handles.
    // We want the other views in the window to stay the same size. If a view is above us, we want it to stay in the same position relative to the top of the window; likewise, if a view is below us, we want it to stay in the same position relative to the bottom of the window.
    // However, views may have their autoresize masks configured differently than we want. So:
    // * For each of the window's content view's immediate subviews,
    //   - Save the current autoresize mask
    //   - And set the autoresize mask how we want
    // * Then resize the window, and fix up the window's min/max sizes.
    // * For each view that we touched earlier, we restore the old autoresize mask.

    NSRect ourFrame;
    NSWindow *window;
    NSView *contentView;
    NSArray *windowSubviews;
    unsigned int windowSubviewCount, windowSubviewIndex;
    NSMutableArray *savedAutoresizeMasks;
    NSRect newWindowFrame;
    NSSize newWindowMinOrMaxSize;

    ourFrame = [self frame];
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

        // We never want to anything to change height.
        autoresizingMask &= ~NSViewHeightSizable;

        if (windowSubview == self || NSMaxY([windowSubview frame]) < NSMaxY(ourFrame)) {
            // This subview is us, or it is below us. Make it stick to the bottom of the window.
            autoresizingMask |= NSViewMaxYMargin;
            autoresizingMask &= ~NSViewMinYMargin;
        } else {
            // This subview is above us. Make it stick to the top of the window.
            autoresizingMask &= ~NSViewMaxYMargin;
            autoresizingMask |= NSViewMinYMargin;
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
        unsigned int autoresizingMask;
        
        windowSubview = [windowSubviews objectAtIndex:windowSubviewIndex];
        autoresizingMask = [[savedAutoresizeMasks objectAtIndex:windowSubviewIndex] unsignedIntValue];
        [windowSubview setAutoresizingMask:autoresizingMask];
    }
}

@end
