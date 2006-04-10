#import <Cocoa/Cocoa.h>


@interface NSPopUpButton (SSEExtensions)

- (void)SSE_addItemWithTitle:(NSString *)title representedObject:(id)object;
- (void)SSE_addSeparatorItem;

@end
