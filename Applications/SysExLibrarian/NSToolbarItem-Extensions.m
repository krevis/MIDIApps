#import "NSToolbarItem-Extensions.h"


@implementation NSToolbarItem (SSEExtensions)

- (void)takeValuesFromDictionary:(NSDictionary *)itemInfo target:(id)target;
{
    NSString *value;
    NSImage *itemImage;
    
    value = [itemInfo objectForKey:@"label"];
    if (value != nil)
        [self setLabel:value];

    value = [itemInfo objectForKey:@"toolTip"];
    if (value != nil)
        [self setToolTip:value];

    value = [itemInfo objectForKey:@"paletteLabel"];
    if (value != nil)
        [self setPaletteLabel:value];

    value = [itemInfo objectForKey:@"target"];
    if ([value isEqualToString:@"FirstResponder"] == YES)
        [self setTarget:nil];
    else if (value && [target respondsToSelector:NSSelectorFromString(value)])
        [self setTarget:[target performSelector:NSSelectorFromString(value)]];
    else
        [self setTarget:target];

    value = [itemInfo objectForKey:@"action"];
    if (value != nil)
        [self setAction:NSSelectorFromString(value)];

    value = [itemInfo objectForKey:@"imageName"];
    if (value != nil) {
        itemImage = [NSImage imageNamed:value];
        [self setImage:itemImage];
    }
}

@end
