#import <Cocoa/Cocoa.h>


@interface SNDisclosableView : NSView
{
    BOOL isShown;
    float originalHeight;
    float hiddenHeight;
    NSArray *hiddenSubviews;
    NSView *nonretainedOriginalNextKeyView;
    NSView *nonretainedLastChildKeyView;
    NSSize sizeBeforeHidden;
}

- (BOOL)isShown;
- (void)setIsShown:(BOOL)value;

- (float)hiddenHeight;
- (void)setHiddenHeight:(float)value;

// Actions
- (IBAction)toggleDisclosure:(id)sender;
- (IBAction)hide:(id)sender;
- (IBAction)show:(id)sender;

@end
