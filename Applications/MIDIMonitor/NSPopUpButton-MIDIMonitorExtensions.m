#import "NSPopUpButton-MIDIMonitorExtensions.h"

#import <Cocoa/Cocoa.h>


@implementation NSPopUpButton (SMMExtensions)

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
    NSArray *array;
    int index, count;

    array = [self itemArray];
    count = [array count];
    for (index = 0; index < count; index++)
        if ([[array objectAtIndex:index] tag] == tag) {
            [self selectItemAtIndex:index];
            return;
        }
}

@end
