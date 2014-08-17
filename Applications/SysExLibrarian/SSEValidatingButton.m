/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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

- (NSInteger)tag;
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
    validator = [NSApp targetForAction:action to:[self target] from:self];

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
