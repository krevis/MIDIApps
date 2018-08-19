/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMDetailsWindowController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMDocument.h"
#import "SMMPreferencesWindowController.h"
#import "SMMSysExWindowController.h"

@interface SMMDetailsWindowController ()

@property (nonatomic, assign) IBOutlet NSTextField *timeField;
@property (nonatomic, assign) IBOutlet NSTextField *sizeField;
@property (nonatomic, assign) IBOutlet NSTextView *textView;

@end

@implementation SMMDetailsWindowController

+ (BOOL)canShowDetailsForMessage:(SMMessage *)inMessage
{
    return ([self subclassForMessage:inMessage] != Nil);
}

+ (SMMDetailsWindowController *)detailsWindowControllerWithMessage:(SMMessage *)inMessage
{
    return [[[[self subclassForMessage:inMessage] alloc] initWithMessage:inMessage] autorelease];
}

- (id)initWithMessage:(SMMessage *)inMessage
{
    if ((self = [super initWithWindowNibName:[[self class] windowNibName]])) {
        _message = [inMessage retain];

        self.shouldCascadeWindows = YES;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayPreferencesDidChange:) name:SMMDisplayPreferenceChangedNotification object:nil];
    }

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SMMDisplayPreferenceChangedNotification object:nil];

    [_message release];
    _message = nil;

    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self synchronizeDescriptionFields];

    [self.textView setString:[self formatData:[self dataForDisplay]]];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
    return [displayName stringByAppendingString:@" Details"];
}

- (void)window:(NSWindow *)window willEncodeRestorableState:(NSCoder *)state
{
    [self.midiDocument encodeRestorableState:state forDetailsWindowController:self];
}

//
// To be overridden by subclasses
//

+ (NSString *)windowNibName
{
    return @"Details";
}

- (NSData *)dataForDisplay
{
    return self.message.otherData;
}

#pragma mark Private

+ (Class)subclassForMessage:(SMMessage *)inMessage
{
    if ([inMessage isKindOfClass:[SMSystemExclusiveMessage class]]) {
        return [SMMSysExWindowController class];
    } else {
        return [SMMDetailsWindowController class];
    }
}

- (SMMDocument *)midiDocument
{
    return (SMMDocument *)self.document;
}

- (void)displayPreferencesDidChange:(NSNotification *)notification
{
    [self synchronizeDescriptionFields];
}

- (void)synchronizeDescriptionFields
{
    NSString *sizeString = [NSString stringWithFormat:
        NSLocalizedStringFromTableInBundle(@"%@ bytes", @"MIDIMonitor", SMBundleForObject(self), "Details size format string"),
        [SMMessage formatLength:self.dataForDisplay.length]];

    self.sizeField.stringValue = sizeString;
    self.timeField.stringValue = self.message.timeStampForDisplay;
}

- (NSString *)formatData:(NSData *)data
{
    NSUInteger dataLength = data.length;
    if (dataLength == 0) {
        return @"";
    }

    const unsigned char *bytes = data.bytes;

    // Figure out how many bytes dataLength takes to represent
    int lengthDigitCount = 0;
    NSUInteger scratchLength = dataLength;
    while (scratchLength > 0) {
        lengthDigitCount += 2;
        scratchLength >>= 8;
    }

    NSMutableString *formattedString = [NSMutableString string];
    for (NSUInteger dataIndex = 0; dataIndex < dataLength; dataIndex += 16) {
        // This C stuff may be a little ugly but it is a hell of a lot faster than doing it with NSStrings...

        static const char hexchars[] = "0123456789ABCDEF";
        char lineBuffer[100];
        char *p = lineBuffer;

        p += sprintf(p, "%.*lX", lengthDigitCount, (unsigned long)dataIndex);
        
        for (NSUInteger index = dataIndex; index < dataIndex+16; index++) {
            *p++ = ' ';
            if (index % 8 == 0) {
                *p++ = ' ';
            }

            if (index < dataLength) {
                unsigned char byte = bytes[index];
                *p++ = hexchars[(byte & 0xF0) >> 4];
                *p++ = hexchars[byte & 0x0F];
            } else {
                *p++ = ' ';
                *p++ = ' ';                                
            }
        }

        *p++ = ' ';
        *p++ = ' ';
        *p++ = '|';

        for (NSUInteger index = dataIndex; index < dataIndex+16 && index < dataLength; index++) {
            unsigned char byte = bytes[index];
            *p++ = (isprint(byte) ? byte : ' ');
        }
        
        *p++ = '|';
        *p++ = '\n';
        *p++ = 0;

        NSString *lineString = [[NSString alloc] initWithCString:lineBuffer encoding:NSASCIIStringEncoding];
        [formattedString appendString:lineString];
        [lineString release];
    }

    return formattedString;
}

@end
