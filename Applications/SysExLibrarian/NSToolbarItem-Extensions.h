#import <Cocoa/Cocoa.h>


@interface NSToolbarItem (SSEExtensions)

- (void)SSE_takeValuesFromDictionary:(NSDictionary *)itemInfo target:(id)target;

@end
