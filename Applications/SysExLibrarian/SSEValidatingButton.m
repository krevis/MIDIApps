#import "SSEValidatingButton.h"


@implementation SSEValidatingButton

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidUpdateNotification object:nil];
    [originalKeyEquivalent release];

    [super dealloc];
}

- (void)awakeFromNib;
{
    NSWindow *window;

    if ([[self superclass] instancesRespondToSelector:@selector(awakeFromNib)])
        [super awakeFromNib];

    if ((window = [self window]))
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidUpdate:) name:NSWindowDidUpdateNotification object:window];

    originalKeyEquivalent = [[NSString alloc] initWithString:[self keyEquivalent]];
}

// There seems to be a compiler bug: it isn't noticing that our superclass (NSControl) implements these methods (which are part of the NSValidatedUserInterfaceItem protocol). Grrrrr!

- (SEL)action;
{
    return [super action];
}

- (int)tag;
{
    return [super tag];
}

@end


@implementation SSEValidatingButton (NotificationsDelegatesDatasources)

- (void)windowDidUpdate:(NSNotification *)notification;
{
    SEL action;
    id validator;
    BOOL shouldBeEnabled;

    action = [self action];
    validator = [[NSApplication sharedApplication] targetForAction:action to:[self target] from:self];

    if ((action == NULL) || (validator == nil) || ![validator respondsToSelector:action]) {
        shouldBeEnabled = NO;
    } else if ([validator respondsToSelector:@selector(validateUserInterfaceItem:)]) {
        shouldBeEnabled = [validator validateUserInterfaceItem:self];
    } else {
        shouldBeEnabled = YES;
    }

    [self setEnabled:shouldBeEnabled];
    [self setKeyEquivalent:(shouldBeEnabled ? originalKeyEquivalent : @"")];
}

@end
