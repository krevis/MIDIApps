#import <Cocoa/Cocoa.h>


@interface NSToolbarItem (SSEExtensions)

- (void)takeValuesFromDictionary:(NSDictionary *)itemInfo target:(id)target;

@end
