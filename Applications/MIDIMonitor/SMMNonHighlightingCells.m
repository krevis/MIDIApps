#import "SMMNonHighlightingCells.h"


@implementation SMMNonHighlightingButtonCell

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
    return [(NSTableView *)controlView backgroundColor];
}

@end


@implementation SMMNonHighlightingTextFieldCell

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
    return [(NSTableView *)controlView backgroundColor];
}

@end
