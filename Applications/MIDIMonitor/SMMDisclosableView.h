#import <Cocoa/Cocoa.h>


@interface SMMDisclosableView : NSView
{
    BOOL isShown;
    double originalHeight;
    double hiddenHeight;
    NSArray *hiddenSubviews;
    NSView *nonretainedOriginalNextKeyView;
    NSView *nonretainedLastChildKeyView;
    NSSize sizeBeforeHidden;
}

- (BOOL)isShown;
- (void)setIsShown:(BOOL)value;

- (double)hiddenHeight;
- (void)setHiddenHeight:(double)value;

// Actions
- (IBAction)toggleDisclosure:(id)sender;
- (IBAction)hide:(id)sender;
- (IBAction)show:(id)sender;

@end

