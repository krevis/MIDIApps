#import "SMMFastAnimatingWindow.h"


@implementation SMMFastAnimatingWindow

- (void)awakeFromNib;
{
    if ([[self superclass] instancesRespondToSelector:@selector(awakeFromNib)])
        [super awakeFromNib];

    animationResizeTimeScaleFactor = 0.75;
}

- (NSTimeInterval)animationResizeTime:(NSRect)newFrame;
{
    return [super animationResizeTime:newFrame] * animationResizeTimeScaleFactor;
}

- (double)animationResizeTimeScaleFactor;
{
    return animationResizeTimeScaleFactor;
}

- (void)setAnimationResizeTimeScaleFactor:(double)value;
{
    animationResizeTimeScaleFactor = value;
}

@end
