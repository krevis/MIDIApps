#import <Cocoa/Cocoa.h>


@interface NSPopUpButton (SSEExtensions)

- (void)addItemWithTitle:(NSString *)title representedObject:(id)object;
- (void)addSeparatorItem;

- (void)selectItemWithTag:(int)tag;

@end
