#import "SMMSourcesOutlineView.h"


@implementation SMMSourcesOutlineView

// NSOutlineView overrides

- (void)highlightSelectionInClipRect:(NSRect)rect;
{
    // Do nothing
}

- (void)mouseDown:(NSEvent *)event;
{
    // Ignore all double-clicks (and triple-clicks and so on) by pretending they are single-clicks.
    if ([event clickCount] > 1) {
        event = [NSEvent mouseEventWithType:[event type] location:[event locationInWindow] modifierFlags:[event modifierFlags] timestamp:[event timestamp] windowNumber:[event windowNumber] context:[event context] eventNumber:[event eventNumber] clickCount:1 pressure:[event pressure]];
    }

    [super mouseDown:event];
}

@end
