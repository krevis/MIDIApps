//
//  SNDisclosureButton.m
//  DisclosableView
//
//  Created by Kurt Revis on Mon Jul 15 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SNDisclosureButton.h"


@interface SNDisclosureButton (Private)

- (void)configureDisclosureButton;
- (NSImage *)imageNamed:(NSString *)imageName;

@end


@implementation SNDisclosureButton

- (id)initWithFrame:(NSRect)frame
{
    if (!(self = [super initWithFrame:frame]))
        return nil;

    [self configureDisclosureButton];
    
    return self;
}

- (void)awakeFromNib
{
    [self configureDisclosureButton];
}

@end


@implementation SNDisclosureButton (Private)

- (void)configureDisclosureButton
{
    NSImage *image;

    if ((image = [self imageNamed:@"SNDisclosureArrowRight"]))
        [self setImage:image];

    if ((image = [self imageNamed:@"SNDisclosureArrowDown"]))
        [self setAlternateImage:image];

    [[self cell] setHighlightsBy:NSPushInCellMask];    
}

- (NSImage *)imageNamed:(NSString *)imageName
{
    NSBundle *bundle;
    NSString *imagePath;
    NSImage *image = nil;

    bundle = [NSBundle bundleForClass:[self class]];
    imagePath = [bundle pathForImageResource:imageName];
    if (imagePath) {        
        image = [[[NSImage alloc] initByReferencingFile:imagePath] autorelease];
        if (!image)
            NSLog(@"SNDisclosureButton: couldn't read image: %@", imagePath);
    } else {
        NSLog(@"SNDisclosureButton: couldn't find image: %@", imageName);
    }

    return image;
}

@end
