#import "SSETableView.h"


@interface SSETableView (Private)

- (void)_deleteSelectedRows;

- (void)_setDrawsDraggingHighlight:(BOOL)value;

@end


@implementation SSETableView

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

- (void)mouseDown:(NSEvent *)event;
{
    // Workaround for bug where triple-click aborts double-click's edit session instead of selecting all of the text in the column to be edited

    if ([event clickCount] < 3)
        [super mouseDown:event];
    else if (_editingCell)
        [[[self window] firstResponder] selectAll:nil];
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
    [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)deleteForward:(id)sender;
{
    [self _deleteSelectedRows];
}

- (void)deleteBackward:(id)sender;
{
    [self _deleteSelectedRows];
}

//
// Dragging
//

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    if (flags.dataSourceCanDrag)
        draggingOperation = [[self dataSource] tableView:self draggingEntered:sender];
    else
        draggingOperation = NSDragOperationNone;

    if (draggingOperation != NSDragOperationNone)
        [self _setDrawsDraggingHighlight:YES];

    return draggingOperation;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    return draggingOperation;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self _setDrawsDraggingHighlight:NO];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    if (flags.dataSourceCanDrag)
        return [[self dataSource] tableView:self performDragOperation:sender];
    else
        return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    [self _setDrawsDraggingHighlight:NO];
}

@end


@implementation SSETableView (Private)

- (void)_deleteSelectedRows;
{
    if (flags.dataSourceCanDeleteRows) {
        NSArray *selectedRows;

        selectedRows = [[self selectedRowEnumerator] allObjects];
        [[self dataSource] tableView:self deleteRows:selectedRows];
    }
}

- (void)_setDrawsDraggingHighlight:(BOOL)value;
{
    if (value != flags.drawsDraggingHighlight) {
        flags.drawsDraggingHighlight = value;
        [self setNeedsDisplay:YES];
    }
}

@end
