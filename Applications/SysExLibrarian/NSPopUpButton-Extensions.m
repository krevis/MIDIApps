#import "NSPopUpButton-Extensions.h"


@implementation NSPopUpButton (SSEExtensions)

- (void)SSE_addItemWithTitle:(NSString *)title representedObject:(id)object;
{
    // NOTE We should just do this, but as of 10.1.3 (and before) it can fail:
    //    [self addItemWithTitle:title];
    // If there is already an item with the same title in the menu, it will be removed when this one is added.

    [self addItemWithTitle:@"*** Placeholder ***"];
    [[self lastItem] setTitle:title];

    [[self lastItem] setRepresentedObject:object];
}

- (void)SSE_addSeparatorItem;
{
    [[self menu] addItem:[NSMenuItem separatorItem]];
}

@end
