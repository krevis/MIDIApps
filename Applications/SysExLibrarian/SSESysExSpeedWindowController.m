/*
 Copyright (c) 2003-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SSESysExSpeedWindowController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>


@interface  SSESysExSpeedWindowController (Private)

- (void)synchronizeControls;

- (void)captureExternalDevices;

- (void)externalDeviceChanged:(NSNotification *)notification;
- (void)externalDeviceListChanged:(NSNotification *)notification;

- (void) forceCoreMIDIToUseNewSysExSpeed;

@end


@implementation SSESysExSpeedWindowController

static SSESysExSpeedWindowController *controller = nil;

+ (SSESysExSpeedWindowController *)sysExSpeedWindowController;
{
    if (!controller)
        controller = [[self alloc] init];
    
    return controller;
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"SysExSpeed"]))
        return nil;

//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalDeviceListChanged:) name:SMMIDIObjectListChangedNotification object:[SMExternalDevice class]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalDeviceListChanged:) name:SMMIDIObjectListChangedNotification object:[SMDestinationEndpoint class]];

    [self captureExternalDevices];
    
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
    [externalDevices release];
    
    [super dealloc];
}

- (IBAction)showWindow:(id)sender;
{
    [self window];	// Make sure the window gets loaded the first time
    [self synchronizeControls];
    [super showWindow:sender];
}

//
// Actions
//


@end


@implementation SSESysExSpeedWindowController (DelegatesNotificationsDataSources)

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [externalDevices count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    SMExternalDevice *device = [externalDevices objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];
    id objectValue = nil;

    if ([identifier isEqualToString:@"name"]) {
        objectValue = [device name];
    } else if ([identifier isEqualToString:@"speed"]) {
        objectValue = [NSNumber numberWithInt:[device maxSysExSpeed]];
    }

    return objectValue;    
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    SMExternalDevice *device = [externalDevices objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];

    if ([identifier isEqualToString:@"speed"]) {
        // TODO validation!  is there a formatter on this thing?
        
        int newValue = [object intValue];
        if (newValue != [device maxSysExSpeed])
        {
            [device setMaxSysExSpeed:newValue];
         
            [self forceCoreMIDIToUseNewSysExSpeed];     // workaround for bug
        }
    }
}

@end


@implementation SSESysExSpeedWindowController (Private)

- (void)synchronizeControls;
{
    [tableView reloadData];
}

- (void)captureExternalDevices;
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSEnumerator *enumerator = [externalDevices objectEnumerator];
    SMExternalDevice *device;

    while ((device = [enumerator nextObject])) {
        [center removeObserver:self name:SMMIDIObjectPropertyChangedNotification object:device];
    }
    
    externalDevices = [[SMExternalDevice externalDevices] retain];

    enumerator = [externalDevices objectEnumerator];
    while ((device = [enumerator nextObject])) {
        [center addObserver:self selector:@selector(externalDeviceChanged:) name:SMMIDIObjectPropertyChangedNotification object:device];
    }
}

- (void)externalDeviceChanged:(NSNotification *)notification
{
    NSString* propertyName = [[notification userInfo] objectForKey:SMMIDIObjectChangedPropertyName];
    if ([propertyName isEqualToString:(NSString *)kMIDIPropertyName] || [propertyName isEqualToString:(NSString *)kMIDIPropertyMaxSysExSpeed]) {
        [self finishEditingInWindow];
        // TODO want to make sure editing is canceled, not possibly accepted
        // TODO only do a setNeedsDisplay on the rect of the appropriate row, not a full reloadData
        [self synchronizeControls];
    }
}

- (void)externalDeviceListChanged:(NSNotification *)notification
{
    // TODO (krevis) shouldn't this redo -captureExternalDevices?
    
    [externalDevices release];
    externalDevices = [[SMExternalDevice externalDevices] retain];

    [self finishEditingInWindow];
    [tableView deselectAll:nil];
    [self synchronizeControls];    
}

- (void) forceCoreMIDIToUseNewSysExSpeed
{
    // The CoreMIDI client caches the last device that was given to MIDISendSysex(), along with its max sysex speed.
    // So when we change the speed, it doesn't notice and continues to use the old speed.
    // To fix this, we send a tiny sysex message to a different device. In fact we can get away with a NULL device.

    NS_DURING
    {
        SMSystemExclusiveMessage* message = [SMSystemExclusiveMessage systemExclusiveMessageWithTimeStamp: 0 data: [NSData data]];
        [[SMSysExSendRequest sysExSendRequestWithMessage: message endpoint: nil] send];
    } NS_HANDLER {
        // don't care
    } NS_ENDHANDLER;
}

@end
