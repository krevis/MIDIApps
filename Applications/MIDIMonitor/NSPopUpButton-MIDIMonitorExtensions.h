#import <Cocoa/Cocoa.h>


@interface NSPopUpButton (SMMExtensions)

- (void)addItemWithTitle:(NSString *)title representedObject:(id)object;
- (void)addSeparatorItem;

- (void)selectItemWithTag:(int)tag;

@end
