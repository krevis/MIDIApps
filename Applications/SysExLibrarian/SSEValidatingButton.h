#import <Cocoa/Cocoa.h>


@interface SSEValidatingButton : NSButton <NSValidatedUserInterfaceItem>
{
    NSString *originalKeyEquivalent;
}

@end
