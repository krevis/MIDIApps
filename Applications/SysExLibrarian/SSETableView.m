#import "SSETableView.h"


@interface SSETableView (Private)

- (void)_deleteSelectedRows;

@end


@implementation SSETableView

- (id)initWithFrame:(NSRect)rect;
{
    if (!(self = [super initWithFrame:rect]))
        return nil;

    flags.shouldEditNextItemWhenEditingEnds = NO;
    flags.dataSourceCanDeleteRows = NO;

    return self;
}

- initWithCoder:(NSCoder *)coder;
{
    if (!(self = [super initWithCoder:coder]))
        return nil;

    flags.shouldEditNextItemWhenEditingEnds = NO;
    flags.dataSourceCanDeleteRows = NO;

    return self;
}

- (void)setDataSource:(id)aSource;
{
    [super setDataSource:aSource];
    flags.dataSourceCanDeleteRows = [[self dataSource] respondsToSelector:@selector(tableView:deleteRows:)];
}

- (BOOL)shouldEditNextItemWhenEditingEnds;
{
    return flags.shouldEditNextItemWhenEditingEnds;
}

- (void)setShouldEditNextItemWhenEditingEnds:(BOOL)value;
{
    flags.shouldEditNextItemWhenEditingEnds = value;
}


// NSTableView overrides

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

@end
