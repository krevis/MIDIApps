#import <Cocoa/Cocoa.h>


@interface SSETableView : NSTableView
{
    struct {
        unsigned int shouldEditNextItemWhenEditingEnds:1;
        unsigned int dataSourceCanDeleteRows:1;
        unsigned int drawsDraggingHighlight:1;
    } flags;
}

- (BOOL)shouldEditNextItemWhenEditingEnds;
- (void)setShouldEditNextItemWhenEditingEnds:(BOOL)value;

- (BOOL)drawsDraggingHighlight;
- (void)setDrawsDraggingHighlight:(BOOL)value;

@end


@interface NSObject (SSETableViewDataSource)

- (void)tableView:(NSTableView *)tableView deleteRows:(NSArray *)rows;

@end
