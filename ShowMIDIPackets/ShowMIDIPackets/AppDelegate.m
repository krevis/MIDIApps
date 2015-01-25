//
//  AppDelegate.m
//  ShowMIDIPackets
//
//  Created by Kurt Revis on 1/24/15.
//  Copyright (c) 2015 Kurt Revis. All rights reserved.
//

#import "AppDelegate.h"
#import "MessageParser.h"
#import <CoreMIDI/CoreMIDI.h>


@interface AppDelegate () <MessageParserDelegate>

@property (weak) IBOutlet NSWindow *window;

@property (nonatomic) IBOutlet NSPopUpButton *sourcePopUpButton;
@property (nonatomic) IBOutlet NSTextView *textView;

@property (nonatomic) MessageParser *parser;

@end


@implementation AppDelegate
{
    MIDIClientRef _clientRef;
    MIDIPortRef _portRef;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.textView.font = [NSFont fontWithName:@"Menlo" size:11];

    NSString* timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterLongStyle];
    [self appendFormat:@"START ShowMIDIPackets at %@", timestamp];

    self.parser = [[MessageParser alloc] init];
    self.parser.delegate = self;

    OSStatus status = MIDIClientCreate(CFSTR("ShowMIDIPackets"), NULL, NULL, &_clientRef);
    if (status != noErr || !_clientRef) {
        [self quitWithMessage:[NSString stringWithFormat:@"Couldn't MIDIClientCreate(): status %d, returned clientRef %d", (int)status, _clientRef]];
    }

    [self appendString:@"Created MIDI client"];

    ItemCount sourceCount = MIDIGetNumberOfSources();
    [self appendFormat:@"Found %lu MIDI sources:", sourceCount];

    if (sourceCount == 0) {
        [self quitWithMessage:@"Found no MIDI sources. Connect one and try again."];
    }

    for (ItemCount i = 0; i < sourceCount; i++) {
        MIDIEndpointRef endpoint = MIDIGetSource(i);
        if (!endpoint) {
            [self quitWithMessage:[NSString stringWithFormat:@"Got NULL endpoint from MIDIGetSource(%lu)", i]];
        }

        CFStringRef name = NULL;
        status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name);
        if (status != noErr) {
            [self quitWithMessage:[NSString stringWithFormat:@"Couldn't MIDIObjectGetStringProperty(): status %d", (int)status]];
        }
        [self appendFormat:@"  %lu: %@", i, name];

        [self.sourcePopUpButton addItemWithTitle:[NSString stringWithFormat:@"%lu: %@", i, (__bridge NSString *)name]];
    }

    [self appendString:@"*** Choose a MIDI source from the popup above. ***\n"];
}

- (IBAction)chooseMIDISource:(id)sender
{
    NSInteger i = [self.sourcePopUpButton indexOfSelectedItem];
    if (i <= 0) {
        return; // in case NSPopUpButton is weird
    }

    NSString *title = [self.sourcePopUpButton titleOfSelectedItem];
    [self appendFormat:@"Chose MIDI source: %@", title];

    self.sourcePopUpButton.title = title;
    self.sourcePopUpButton.enabled = NO;

    // pull-down menu has title as first item, so adjust by 1
    MIDIEndpointRef endpoint = MIDIGetSource(i - 1);
    if (!endpoint) {
        [self quitWithMessage:[NSString stringWithFormat:@"Got NULL endpoint from MIDIGetSource(%lu)", i]];
    }

    [self appendFormat:@"Got endpoint %u", (unsigned int)endpoint];

    OSStatus status = MIDIInputPortCreate(_clientRef, CFSTR("Input Port"), midiReadProc, (__bridge void *)self, &_portRef);
    if (status != noErr || !_portRef) {
        [self quitWithMessage:[NSString stringWithFormat:@"Couldn't MIDIInputPortCreate(): status %d, returned portRef %d", (int)status, _portRef]];
    }

    status = MIDIPortConnectSource(_portRef, endpoint, NULL);
    if (status != noErr) {
        [self quitWithMessage:[NSString stringWithFormat:@"Couldn't MIDIPortConnectSource(): status %d", (int)status]];
    }

    [self appendString:@"Connected input port to MIDI source"];
    [self appendString:@"*** Now send MIDI from your source. ***\n"];
}

- (IBAction)save:(id)sender
{
    if (self.textView.string.length <= 0) {
        return;
    }

    NSSavePanel* sp = [NSSavePanel savePanel];
    sp.nameFieldStringValue = @"ShowMIDIPackets output";
    sp.allowedFileTypes = @[@"txt"];
    sp.allowsOtherFileTypes = YES;
    sp.canSelectHiddenExtension = YES;
    sp.extensionHidden = NO;

    [sp beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString* timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterLongStyle];
            [self appendFormat:@"\nSAVE ShowMIDIPackets at %@\n", timestamp];

            NSError* error = nil;
            if (![self.textView.string writeToURL:sp.URL atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
                [[NSAlert alertWithError:error] runModal];
            }
        }
    }];
}

#pragma mark -

static void midiReadProc(const MIDIPacketList *packetList, void *readProcRefCon, void *srcConnRefCon)
{
    // Called on the MIDI thread. We need to process on the main thread, but if we do it async we'd need to copy the packet list. To avoid causing any bugs by incorrectly copying the packet list, dispatch_sync.

    dispatch_sync(dispatch_get_main_queue(), ^{
        [(__bridge AppDelegate *)readProcRefCon takePacketList:packetList];
    });
}

- (void)takePacketList:(const MIDIPacketList *)packetList
{
    if (!packetList) {
        [self appendFormat:@"Packet list %p", packetList];
        return;
    }

    [self appendFormat:@"Packet list %p with %u packets", packetList, packetList->numPackets];

    const MIDIPacket *packet = &packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; i++) {
        NSMutableString *formattedData = [NSMutableString string];
        for (int j = 0; j < packet->length; j++) {
            [formattedData appendFormat:@"%02X ", packet->data[j]];
        }

        [self appendFormat:@"  Packet %d: time %llu, length %u, data %@", i, packet->timeStamp, (unsigned)packet->length, formattedData];

        packet = MIDIPacketNext(packet);
    }

    [self.parser takePacketList:packetList];
}

- (void)parser:(MessageParser *)parser didReadMessages:(NSArray *)messages
{
    if (!messages) {
        [self appendFormat:@"Parser: nil messages"];
    } else if (messages.count == 0) {
        [self appendFormat:@"Parser: empty messages array"];
    } else {
        for (NSString *message in messages) {
            [self appendFormat:@"  Parser: %@", message];
        }
    }
}


#pragma mark -

- (void)quitWithMessage:(NSString *)message
{
    NSAlert* alert = [NSAlert alertWithMessageText:@"Error" defaultButton:@"Quit" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", message];
    [alert runModal];
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)appendString:(NSString *)message
{
    if (message) {
        [self.textView replaceCharactersInRange:NSMakeRange(self.textView.string.length, 0) withString:[message stringByAppendingString:@"\n"]];
        [self.textView scrollRangeToVisible:NSMakeRange(self.textView.string.length, 0)];
    }
}

- (void)appendFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2)
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    [self appendString:message];
    va_end(args);
}

@end
