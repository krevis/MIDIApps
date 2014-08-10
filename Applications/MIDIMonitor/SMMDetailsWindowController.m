/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMDetailsWindowController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMPreferencesWindowController.h"
#import "SMMSysExWindowController.h"


@interface SMMDetailsWindowController (Private)

+ (Class)subclassForMessage:(SMMessage *)inMessage;

- (void)displayPreferencesDidChange:(NSNotification *)notification;

- (void)synchronizeDescriptionFields;

- (NSString *)formatData:(NSData *)data;

@end


@implementation SMMDetailsWindowController

static NSMapTable* messageToControllerMapTable = NULL;


+ (BOOL)canShowDetailsForMessage:(SMMessage *)inMessage
{
    return ([self subclassForMessage:inMessage] != Nil);
}

+ (SMMDetailsWindowController *)detailsWindowControllerWithMessage:(SMMessage *)inMessage
{
    SMMDetailsWindowController *controller;

    if (!messageToControllerMapTable) {
        messageToControllerMapTable = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);
    }

    controller = NSMapGet(messageToControllerMapTable, inMessage);
    if (!controller) {
        controller = [[[self subclassForMessage:inMessage] alloc] initWithMessage:inMessage];
        if (controller) {
            NSMapInsertKnownAbsent(messageToControllerMapTable, inMessage, controller);
            [controller release];            
        }
    }

    return controller;
}

- (id)initWithMessage:(SMMessage *)inMessage;
{
    if (!(self = [super initWithWindowNibName:[[self class] windowNibName]]))
        return nil;

    message = [inMessage retain];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayPreferencesDidChange:) name:SMMDisplayPreferenceChangedNotification object:nil];
    
    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [message release];
    message = nil;
    
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    // Try to change the main text's font from Monaco 10 to Menlo 10,
    // which looks a lot better, but is only available on 10.6 and later.
    NSFont* menloFont = [NSFont fontWithName:@"Menlo-Regular" size:10.];
    if (menloFont)
        [textView setFont:menloFont];

    [self synchronizeDescriptionFields];

    [textView setString:[self formatData:[self dataForDisplay]]];
}

- (SMMessage *)message;
{
    return message;
}

//
// To be overridden by subclasses
//

+ (NSString *)windowNibName
{
    return @"Details";
}

- (NSData *)dataForDisplay;
{
    return [message otherData];
}

@end


@implementation SMMDetailsWindowController (NotificationsDelegatesDataSources)

- (void)windowWillClose:(NSNotification *)notification;
{
    [[self retain] autorelease];
    NSMapRemove(messageToControllerMapTable, self);
}

@end


@implementation SMMDetailsWindowController (Private)

+ (Class)subclassForMessage:(SMMessage *)inMessage
{
    if ([inMessage isKindOfClass:[SMInvalidMessage class]])
        return [SMMDetailsWindowController class];
    else if ([inMessage isKindOfClass:[SMSystemExclusiveMessage class]])
        return [SMMSysExWindowController class];
    else
        return Nil;
}

- (void)displayPreferencesDidChange:(NSNotification *)notification;
{
    [self synchronizeDescriptionFields];
}

- (void)synchronizeDescriptionFields;
{
    NSString *sizeString = [NSString stringWithFormat:
        NSLocalizedStringFromTableInBundle(@"%@ bytes", @"MIDIMonitor", SMBundleForObject(self), "Details size format string"),
        [SMMessage formatLength:[[self dataForDisplay] length]]];

    [sizeField setStringValue:sizeString];

    [timeField setStringValue:[message timeStampForDisplay]];
}

- (NSString *)formatData:(NSData *)data;
{
    NSUInteger dataLength;
    const unsigned char *bytes;
    NSMutableString *formattedString;
    NSUInteger dataIndex;
    int lengthDigitCount;
    NSUInteger scratchLength;

    dataLength = [data length];
    if (dataLength == 0)
        return @"";

    bytes = [data bytes];

    // Figure out how many bytes dataLength takes to represent
    lengthDigitCount = 0;
    scratchLength = dataLength;
    while (scratchLength > 0) {
        lengthDigitCount += 2;
        scratchLength >>= 8;
    }

    formattedString = [NSMutableString string];
    for (dataIndex = 0; dataIndex < dataLength; dataIndex += 16) {
        static const char hexchars[] = "0123456789ABCDEF";
        char lineBuffer[100];
        char *p;
        unsigned int index;
        NSString *lineString;

        // This C stuff may be a little ugly but it is a hell of a lot faster than doing it with NSStrings...

        p = lineBuffer;
        p += sprintf(p, "%.*lX", lengthDigitCount, (unsigned long)dataIndex);
        
        for (index = dataIndex; index < dataIndex+16; index++) {
            *p++ = ' ';
            if (index % 8 == 0)
                *p++ = ' ';

            if (index < dataLength) {
                unsigned char byte;

                byte = bytes[index];
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

        for (index = dataIndex; index < dataIndex+16 && index < dataLength; index++) {
            unsigned char byte;

            byte = bytes[index];
            *p++ = (isprint(byte) ? byte : ' ');
        }
        
        *p++ = '|';
        *p++ = '\n';
        *p++ = 0;

        lineString = [[NSString alloc] initWithCString:lineBuffer encoding:NSASCIIStringEncoding];
        [formattedString appendString:lineString];
        [lineString release];
    }

    return formattedString;
}

@end
