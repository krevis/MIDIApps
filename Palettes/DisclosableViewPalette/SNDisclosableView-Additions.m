/*
 Copyright (c) 2002, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Snoize nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SNDisclosableView-Additions.h"
#import <InterfaceBuilder/IBViewAdditions.h>
#import <InterfaceBuilder/IBObjectAdditions.h>
#import <InterfaceBuilder/IBApplicationAdditions.h>


@interface NSView (UndocumentedIBAdditions)

- (BOOL)editorHandlesCaches;

@end


@implementation SNDisclosableView (IBPaletteAdditions)

- (void)drawRect:(NSRect)rect;
{
    // Draw differently since we are running in IB.    

    if (![NSApp isTestingInterface] && [[self subviews] count] == 0) {
        // Try to duplicate the way that NSCustomView draws in IB, when it has no subviews.
        NSRect bounds;
        NSFont *font;
        float lineHeight;
        NSRect centeredCellFrame;
        
        // Draw the groove around the outside:
        bounds = [self bounds];
        NSDrawGroove(bounds, rect);

        // Clear the inside (leaving room for the groove):
        bounds = NSInsetRect(bounds, 2.0, 2.0);
        [[NSColor clearColor] set];
        NSRectFill(bounds);
        // and draw over it with translucent gray.
        [[NSColor colorWithDeviceWhite:0.5530 alpha:0.5] set];
            // NOTE This seems to give the same result that NSCustomView does, but of course it's not coded like this.
            // IB apparently uses [NSColor colorUsingColorSpaceName:[NSColor IBDefaultSelectionColor]]
            // (and may then set alpha on it... not sure)
        NSRectFillUsingOperation(bounds, NSCompositeSourceOver);

        // Now draw the name of the class.
        // The text is one line, centered vertically in our bounds,
        font = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
        lineHeight = [font defaultLineHeightForFont];
        centeredCellFrame = NSMakeRect(bounds.origin.x, bounds.origin.y + floor((bounds.size.height - lineHeight) / 2.0), bounds.size.width, lineHeight);

        if (NSIntersectsRect(rect, centeredCellFrame)) {
            NSTextFieldCell *cell;

            cell = [[NSTextFieldCell alloc] initTextCell:NSStringFromClass([self class])];
            [cell setFont:font];
            [cell setAlignment:NSCenterTextAlignment];
            [cell setTextColor:[NSColor whiteColor]];                
            [cell drawWithFrame:centeredCellFrame inView:self];
            [cell release];
        }
    } else {
        [super drawRect:rect];
    }
}

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

- (BOOL)editorHandlesCaches
{
    return YES;
    // The default NSView implementation returns NO, which seems wrong. If we leave it as NO,
    // when editing in IB, our subviews will not get erased when they are moved around.
}

- (NSString *)inspectorClassName;
{
    return @"SNDisclosableViewInspector";
}

// TODO When we resize this view in IB, its subviews may also get moved.
// The editors for NSCustomView and NSBox do not do this (because it's kind of annoying).
// I haven't yet figured out how to fix this, though.

@end
