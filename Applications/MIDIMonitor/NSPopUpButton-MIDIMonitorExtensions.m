#import "NSPopUpButton-MIDIMonitorExtensions.h"

#import <Cocoa/Cocoa.h>


@implementation NSPopUpButton (SMMExtensions)

- (void)addItemWithTitle:(NSString *)title representedObject:(id)object;
{
    [self addItemWithTitle:title];
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
