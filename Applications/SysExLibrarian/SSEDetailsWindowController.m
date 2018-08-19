/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSEDetailsWindowController.h"

#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSELibrary.h"
#import "SSELibraryEntry.h"
#import "CocoaCryptoHashing.h"


@interface SSEDetailsWindowController (Private)

- (void)synchronizeMessageDataDisplay;
- (void)synchronizeTitle;

- (void)entryWillBeRemoved:(NSNotification *)notification;
- (void)entryNameDidChange:(NSNotification *)notification;

- (NSString *)formatSysExData:(NSData *)data;

@end


@implementation SSEDetailsWindowController

static NSMutableArray *controllers = nil;

+ (SSEDetailsWindowController *)detailsWindowControllerWithEntry:(SSELibraryEntry *)inEntry;
{
    NSUInteger controllerIndex;
    SSEDetailsWindowController *controller;

    if (!controllers) {
        controllers = [[NSMutableArray alloc] init];
    }

    controllerIndex = [controllers count];
    while (controllerIndex--) {
        controller = [controllers objectAtIndex:controllerIndex];
        if ([controller entry] == inEntry)
            return controller;
    }

    controller = [[SSEDetailsWindowController alloc] initWithEntry:inEntry];
    [controllers addObject:controller];
    [controller release];

    return controller;
}

- (id)initWithEntry:(SSELibraryEntry *)inEntry;
{
    if (!(self = [super initWithWindowNibName:@"Details"]))
        return nil;

    [self setShouldCascadeWindows:YES];

    entry = [inEntry retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(entryWillBeRemoved:) name:SSELibraryEntryWillBeRemovedNotification object:entry];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(entryNameDidChange:) name:SSELibraryEntryNameDidChangeNotification object:entry];
    
    cachedMessages = [[NSArray alloc] initWithArray:[entry messages]];

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [entry release];
    entry = nil;
    [cachedMessages release];
    cachedMessages = nil;
        
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self synchronizeTitle];
    
    [messagesTableView reloadData];
    if ([cachedMessages count] > 0)
        [messagesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

    [self synchronizeMessageDataDisplay];
}

- (SSELibraryEntry *)entry;
{
    return entry;
}

//
// Actions
//

- (IBAction)selectAll:(id)sender;
{
    // Forward to the text view, even if it isn't the first responder
    [textView selectAll:sender];
}

@end


@implementation SSEDetailsWindowController (NotificationsDelegatesDataSources)

//
// NSWindow delegate
//

- (void)windowWillClose:(NSNotification *)notification;
{
    [[self retain] autorelease];
    [controllers removeObjectIdenticalTo:self];
}

//
// NSTableView data source
//

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [cachedMessages count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    NSString *identifier;
    SMSystemExclusiveMessage *message;

    identifier = [tableColumn identifier];
    message = [cachedMessages objectAtIndex:row];

    if ([identifier isEqualToString:@"index"]) {
        return [NSNumber numberWithInt:row + 1];
    } else if ([identifier isEqualToString:@"manufacturer"]) {
        return [message manufacturerName];
    } else if ([identifier isEqualToString:@"sizeDecimal"]) {
        return [SMMessage formatLength:[message receivedDataWithStartByteLength] usingOption:SMDataFormatDecimal];
    } else if ([identifier isEqualToString:@"sizeHex"]) {
        return [SMMessage formatLength:[message receivedDataWithStartByteLength] usingOption:SMDataFormatHexadecimal];
    } else if ([identifier isEqualToString:@"sizeAbbreviated"]) {
        return [NSString SnoizeMIDI_abbreviatedStringForByteCount:[message receivedDataWithStartByteLength]];
    } else {
        return nil;
    }
}

//
// NSTableView delegate
//

- (void)tableViewSelectionDidChange:(NSNotification *)notification;
{
    [self synchronizeMessageDataDisplay];
}

//
// NSSplitView delegate
//

const CGFloat kMinMessagesViewHeight = 32.f;
const CGFloat kMinTextViewHeight = 32.f;

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return proposedMinimumPosition + kMinMessagesViewHeight;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return proposedMaximumPosition - kMinTextViewHeight;
}

-(void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
    [splitView adjustSubviews];

    NSView* v1 = splitView.subviews[0];
    NSView* v2 = splitView.subviews[1];
    CGRect v1Frame = v1.frame;
    CGRect v2Frame = v2.frame;
    CGFloat dividerThickness = splitView.dividerThickness;
    CGFloat boundsHeight = splitView.bounds.size.height;

    if (v1Frame.size.height < kMinMessagesViewHeight) {
        v1.frame = (CGRect) {
            { v1Frame.origin.x, 0.f },
            { v1Frame.size.width, kMinMessagesViewHeight }
        };
        v2.frame = (CGRect) {
            { v2Frame.origin.x, kMinMessagesViewHeight + dividerThickness },
            { v2Frame.size.width, boundsHeight - (dividerThickness + kMinMessagesViewHeight) }
        };
    } else if (v2Frame.size.height < kMinTextViewHeight) {
        v1.frame = (CGRect) {
            { v1Frame.origin.x, 0.f },
            { v1Frame.size.width, boundsHeight - (dividerThickness + kMinTextViewHeight) }
        };
        v2.frame = (CGRect) {
            { v2Frame.origin.x, boundsHeight - kMinTextViewHeight },
            { v2Frame.size.width, kMinTextViewHeight }
        };
    }
}

@end


@implementation SSEDetailsWindowController (Private)

- (void)synchronizeMessageDataDisplay;
{
    NSInteger selectedRow;
    NSString *formattedData;

    selectedRow = [messagesTableView selectedRow];
    if (selectedRow >= 0) {
        formattedData = [self formatSysExData:[[cachedMessages objectAtIndex:selectedRow] receivedDataWithStartByte]];
    } else {
        formattedData = @"";
    }

    [textView setString:formattedData];
}

- (void)synchronizeTitle;
{
    [[self window] setTitle:[entry name]];
    [[self window] setRepresentedFilename:[entry path]];
}

- (void)entryWillBeRemoved:(NSNotification *)notification;
{
    [self close];
}

- (void)entryNameDidChange:(NSNotification *)notification;
{
    [self synchronizeTitle];
}

- (NSString *)formatSysExData:(NSData *)data;
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
        NSUInteger index;
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

    [formattedString appendFormat: @"\nMD5 checksum:   %@", [data md5HexHash]];
    [formattedString appendFormat: @"\nSHA-1 checksum: %@", [data sha1HexHash]];        
        
    return formattedString;
}

@end
