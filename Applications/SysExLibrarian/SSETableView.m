/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSETableView.h"


@interface SSETableView (Private)

- (void)deleteSelectedRows;

- (void)setDrawsDraggingHighlight:(BOOL)value;

@end


@implementation SSETableView

+ (NSImage *)tableHeaderSortImage;
{
    return [NSImage imageNamed: @"NSAscendingSortIndicator"];
}

+ (NSImage *)tableHeaderReverseSortImage;
{
    return [NSImage imageNamed: @"NSDescendingSortIndicator"];
}

- (id)initWithFrame:(NSRect)rect;
{
    if (!(self = [super initWithFrame:rect]))
        return nil;

    flags.shouldEditNextItemWhenEditingEnds = NO;
    flags.dataSourceCanDeleteRows = NO;
    flags.dataSourceCanDrag = NO;
    flags.drawsDraggingHighlight = NO;

    return self;
}

- initWithCoder:(NSCoder *)coder;
{
    if (!(self = [super initWithCoder:coder]))
        return nil;

    flags.shouldEditNextItemWhenEditingEnds = NO;
    flags.dataSourceCanDeleteRows = NO;
    flags.dataSourceCanDrag = NO;
    flags.drawsDraggingHighlight = NO;
    
    return self;
}

- (void)setDataSource:(id)aSource;
{
    [super setDataSource:aSource];
    
    flags.dataSourceCanDeleteRows = [aSource respondsToSelector:@selector(tableView:deleteRows:)];
    flags.dataSourceCanDrag = ([aSource respondsToSelector:@selector(tableView:draggingEntered:)] && [aSource respondsToSelector:@selector(tableView:performDragOperation:)]);
}

- (BOOL)shouldEditNextItemWhenEditingEnds;
{
    return flags.shouldEditNextItemWhenEditingEnds;
}

- (void)setShouldEditNextItemWhenEditingEnds:(BOOL)value;
{
    flags.shouldEditNextItemWhenEditingEnds = value;
}

- (void)setSortColumn:(NSTableColumn *)sortColumn isAscending:(BOOL)isSortAscending;
{
    NSArray *columns;
    NSUInteger columnIndex;

    columns = [self tableColumns];
    columnIndex = [columns count];
    while (columnIndex--) {
        NSTableColumn *column;
        NSImage *indicatorImage;

        column = [columns objectAtIndex:columnIndex];
        if (column == sortColumn) {
            if (isSortAscending)
                indicatorImage = [[self class] tableHeaderSortImage];
            else
                indicatorImage = [[self class] tableHeaderReverseSortImage];
        } else {
            indicatorImage = nil;
        }

        [self setIndicatorImage:indicatorImage inTableColumn:column];
    }
}

//
// NSTableView overrides
//

- (void)textDidEndEditing:(NSNotification *)notification;
{
    if (flags.shouldEditNextItemWhenEditingEnds == NO && [[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement) {
        // This is ugly, but just about the only way to do it. NSTableView is determined to select and edit something else, even the text field that it just finished editing, unless we mislead it about what key was pressed to end editing.
        NSMutableDictionary *newUserInfo;
        NSNotification *newNotification;

        newUserInfo = [NSMutableDictionary dictionaryWithDictionary:[notification userInfo]];
        [newUserInfo setObject:[NSNumber numberWithInt:NSIllegalTextMovement] forKey:@"NSTextMovement"];
        newNotification = [NSNotification notificationWithName:[notification name] object:[notification object] userInfo:newUserInfo];
        [super textDidEndEditing:newNotification];

        // For some reason we lose firstResponder status when when we do the above.
        [[self window] makeFirstResponder:self];
    } else {
        [super textDidEndEditing:notification];
    }
}

- (void)drawRect:(NSRect)rect;
{
    [super drawRect:rect];

    if (flags.drawsDraggingHighlight) {
        NSRect highlightRect;

        highlightRect = [[self enclosingScrollView] documentVisibleRect];
        [[NSColor selectedControlColor] set];
        NSFrameRectWithWidth(highlightRect, 2.0);
    }
}

- (void)keyDown:(NSEvent *)theEvent;
{
    NSString *characters;
    unichar firstCharacter;

    // We would like to use -interpretKeyEvents:, but then *all* key events would get interpreted into selectors,
    // and NSTableView does not implement the proper selectors (like moveUp: for up arrow). Instead it apparently
    // checks key codes manually in -keyDown. So, we do the same.
    // Key codes are taken from /System/Library/Frameworks/AppKit.framework/Resources/StandardKeyBinding.dict.

    characters = [theEvent characters];
    firstCharacter = [characters characterAtIndex:0];

    if (firstCharacter == 0x08 || firstCharacter == 0x7F)
        // ^H (backspace, BS) or Delete key (DEL)
        [self deleteBackward:self];
    else if (firstCharacter == 0x04 || firstCharacter == 0xF728)
        // ^D (forward delete emacs keybinding) or keypad delete key (which is  0xEF 0x9C 0xA8 in UTF-8)
        [self deleteForward:self];
    else
        [super keyDown:theEvent];
}

- (void)deleteForward:(id)sender;
{
    [self deleteSelectedRows];
}

- (void)deleteBackward:(id)sender;
{
    [self deleteSelectedRows];
}

- (BOOL)respondsToSelector:(SEL)aSelector;
{
    // If we can't do anything useful in response to a selectAll:, then pretend that we don't even respond to it.
    
    if (aSelector == @selector(selectAll:))
        return [self allowsMultipleSelection];
    else
        return [super respondsToSelector:aSelector];
}


//
// Dragging
//

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    if (flags.dataSourceCanDrag)
        draggingOperation = [(id<SSETableViewDataSource>)[self dataSource] tableView:self draggingEntered:sender];
    else
        draggingOperation = NSDragOperationNone;

    if (draggingOperation != NSDragOperationNone)
        [self setDrawsDraggingHighlight:YES];

    return draggingOperation;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    return draggingOperation;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self setDrawsDraggingHighlight:NO];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    if (flags.dataSourceCanDrag)
        return [(id<SSETableViewDataSource>)[self dataSource] tableView:self performDragOperation:sender];
    else
        return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    [self setDrawsDraggingHighlight:NO];
}

@end


@implementation SSETableView (Private)

- (void)deleteSelectedRows;
{
    if (flags.dataSourceCanDeleteRows) {
        [(id<SSETableViewDataSource>)[self dataSource] tableView:self deleteRows:[self selectedRowIndexes]];
    }
}

- (void)setDrawsDraggingHighlight:(BOOL)value;
{
    if (value != flags.drawsDraggingHighlight) {
        flags.drawsDraggingHighlight = value;
        [self setNeedsDisplay:YES];
    }
}

@end
