#import <Cocoa/Cocoa.h>


@interface SSETableView : NSTableView
{
    struct {
        unsigned int shouldEditNextItemWhenEditingEnds:1;
        unsigned int dataSourceCanDeleteRows:1;
        unsigned int dataSourceCanDrag:1;
        unsigned int drawsDraggingHighlight:1;
    } flags;
    NSDragOperation draggingOperation;
}

- (BOOL)shouldEditNextItemWhenEditingEnds;
- (void)setShouldEditNextItemWhenEditingEnds:(BOOL)value;

@end


@interface NSObject (SSETableViewDataSource)

- (void)tableView:(SSETableView *)tableView deleteRows:(NSArray *)rows;

- (NSDragOperation)tableView:(SSETableView *)tableView draggingEntered:(id <NSDraggingInfo>)sender;
- (BOOL)tableView:(SSETableView *)tableView performDragOperation:(id <NSDraggingInfo>)sender;

@end
