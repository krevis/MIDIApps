#import <Cocoa/Cocoa.h>

@interface SMMFastAnimatingWindow : NSWindow
{
    double animationResizeTimeScaleFactor;
}

- (double)animationResizeTimeScaleFactor;
- (void)setAnimationResizeTimeScaleFactor:(double)value;

@end
