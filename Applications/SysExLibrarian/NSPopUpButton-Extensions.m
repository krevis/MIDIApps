#import "NSPopUpButton-Extensions.h"


@implementation NSPopUpButton (SSEExtensions)

- (void)addItemWithTitle:(NSString *)title representedObject:(id)object;
{
    // NOTE We should just do this, but as of 10.1.3 (and before) it can fail:
    //    [self addItemWithTitle:title];
    // If there is already an item with the same title in the menu, it will be removed when this one is added.

    [self addItemWithTitle:@"*** Placeholder ***"];
    [[self lastItem] setTitle:title];

    [[self lastItem] setRepresentedObject:object];
}

- (void)addSeparatorItem;
{
    [[self menu] addItem:[NSMenuItem separatorItem]];
}

- (void)selectItemWithTag:(int)tag
{
    int index = [self indexOfItemWithTag:tag];
    if (tag != -1)
        [self selectItemAtIndex:index];
}

@end
