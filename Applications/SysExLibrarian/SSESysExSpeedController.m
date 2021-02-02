/*
 Copyright (c) 2003-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SSESysExSpeedController.h"
@import SnoizeMIDI;
#import "SysEx_Librarian-Swift.h"
#import "SSEMIDIController.h"
#import "SSEAppController.h"

@interface  SSESysExSpeedController (Private)

- (void)captureEndpointsAndExternalDevices;
- (void)releaseEndpointsAndExternalDevices;
- (void)midiSetupChanged:(NSNotification *)notification;
- (void)midiObjectChanged:(NSNotification *)notification;

- (NSInteger)effectiveSpeedForItem:(MIDIObject*)item;

- (void)invalidateRowAndParent:(NSInteger)row;

@end


@implementation SSESysExSpeedController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [endpoints release];
    [externalDevices release];
    
    [super dealloc];
}

- (void) awakeFromNib
{
    [outlineView setAutoresizesOutlineColumn:NO];

    // Workaround to get continuous updates from the sliders in the table view.
    // You can't just set it, or its cell, to be continuous -- that still doesn't
    // give you continuous updates through the normal table view interface.
    // What DOES work is to have the cell message us directly.
    NSTableColumn* col = [outlineView tableColumnWithIdentifier:@"speed"];
    [[col dataCell] setTarget:self];
    [[col dataCell] setAction:@selector(takeSpeedFromSelectedCellInTableView:)];
}

- (void)willShow
{
    // TODO Can this be more specific now?
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(midiSetupChanged:) name:NSNotification.clientSetupChanged object:[SMClient sharedClient]];

    [self captureEndpointsAndExternalDevices];
     
    [outlineView reloadData];

    NSInteger customBufferSize = [[NSUserDefaults standardUserDefaults] integerForKey:SSECustomSysexBufferSizePreferenceKey];
    [bufferSizePopUpButton selectItemWithTag:customBufferSize];
    if ([bufferSizePopUpButton selectedTag] != customBufferSize) {
        [bufferSizePopUpButton selectItemWithTag:0];
    }
}

- (void)willHide
{
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSNotification.clientSetupChanged object:[SMClient sharedClient]]; // TODO
    
    [self releaseEndpointsAndExternalDevices];
    
    [outlineView reloadData];
}


//
// Actions
//

- (void)takeSpeedFromSelectedCellInTableView:(id)sender
{
    // sender is the outline view; get the selected cell to find its new value.    
    NSCell* cell = [outlineView selectedCell];
    NSInteger newValue = [cell integerValue];
    
    // Don't actually set the value while we're tracking -- no need to update CoreMIDI
    // continuously.  Instead, remember which item is getting tracked and what its value
    // is "supposed" to be.  When tracking finishes, the new value comes through 
    // -outlineView:setObjectValue:..., and we'll set it for real. 
    NSInteger row = [outlineView clickedRow];
    MIDIObject* item = (MIDIObject*)[outlineView itemAtRow:row];
    trackingMIDIObject = item;
    speedOfTrackingMIDIObject = newValue;  

    // update the slider value based on the effective speed (which may be different than the tracking value)
    NSInteger effectiveValue = [self effectiveSpeedForItem:item];
    if (newValue != effectiveValue) {
        [cell setIntegerValue:effectiveValue];
    }    
    
    // redisplay
    [self invalidateRowAndParent:row];
}

- (IBAction)changeBufferSize:(id)sender
{
    NSInteger customBufferSize = [bufferSizePopUpButton selectedTag];
    if (customBufferSize == 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:SSECustomSysexBufferSizePreferenceKey];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setInteger:customBufferSize forKey:SSECustomSysexBufferSizePreferenceKey];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SSECustomSysexBufferSizePreferenceChangedNotification object:nil];
}

@end


@implementation SSESysExSpeedController (DelegatesNotificationsDataSources)

- (id)outlineView:(NSOutlineView *)anOutlineView child:(int)index ofItem:(id)item
{
    id child = nil;
    
    if (item == nil) {
        if (index < [endpoints count]) {
            child = [endpoints objectAtIndex:index];
        }
    } else {
        Destination* endpoint = (Destination*)item;
        NSArray* connectedExternalDevices = [endpoint connectedExternalDevices];
        if (index < [connectedExternalDevices count]) {
            child = [[endpoint connectedExternalDevices] objectAtIndex:index];
        }
    }
    
    return child;
}

- (BOOL)outlineView:(NSOutlineView *)anOutlineView isItemExpandable:(id)item
{
    BOOL isItemExpandable = NO;
    
    if (item == nil) {
        isItemExpandable = YES;
    } else if ([item isKindOfClass:[Destination class]]) {
        Destination* endpoint = (Destination*)item;
        isItemExpandable = ([[endpoint connectedExternalDevices] count] > 0);
    }
    
    return isItemExpandable;    
}

- (NSInteger)outlineView:(NSOutlineView *)anOutlineView numberOfChildrenOfItem:(id)item
{
    NSInteger childCount = 0;
    
    if (item == nil) {
        childCount = [endpoints count];
    } else if ([item isKindOfClass:[Destination class]]) {
        Destination* endpoint = (Destination*)item;
        childCount = [[endpoint connectedExternalDevices] count];
    }

    return childCount;
}

- (id)outlineView:(NSOutlineView *)anOutlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    id objectValue = nil;
    
    if (item && tableColumn) {
        NSString *identifier = [tableColumn identifier];
        
        if ([identifier isEqualToString:@"name"]) {
            objectValue = [item name];
        } else if ([identifier isEqualToString:@"speed"] || [identifier isEqualToString:@"bytesPerSecond"]) {
            objectValue = @([self effectiveSpeedForItem:(MIDIObject*)item]);
        } else if ([identifier isEqualToString:@"percent"]) {
            NSInteger speed = [self effectiveSpeedForItem:(MIDIObject*)item];
            objectValue = @((speed / 3125.0) * 100.0);
        }
    }
        
    return objectValue;
}

- (void)outlineView:(NSOutlineView *)anOutlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if (item && tableColumn) {
        NSString *identifier = [tableColumn identifier];
        
        if ([identifier isEqualToString:@"speed"]) {
            int newValue = [object intValue];
            MIDIObject* midiObject = (MIDIObject*)item;
            if (newValue > 0 && newValue != [midiObject maxSysExSpeed]) {
                [midiObject setMaxSysExSpeed:newValue];
                
                // Work around bug where CoreMIDI doesn't pay attention to the new speed
                MIDIContext *midiContext = [(SSEAppController *)[NSApp delegate] midiContext];
                [midiContext forceCoreMIDIToUseNewSysExSpeed];
            }
            
            trackingMIDIObject = nil;
        }
    }    
}

@end


@implementation SSESysExSpeedController (Private)

- (void)captureEndpointsAndExternalDevices
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSEnumerator *enumerator;
    id midiObject;

    enumerator = [endpoints objectEnumerator];
    while ((midiObject = [enumerator nextObject])) {
        [center removeObserver:self name:NSNotification.midiObjectPropertyChanged object:midiObject];
    }
    
    enumerator = [externalDevices objectEnumerator];
    while ((midiObject = [enumerator nextObject])) {
        [center removeObserver:self name:NSNotification.midiObjectPropertyChanged object:midiObject];
    }
    
    MIDIContext *midiContext = [(SSEAppController *)[NSApp delegate] midiContext];
    endpoints = [[CombinationOutputStream destinationsInContext: midiContext] retain];
    externalDevices = [[midiContext externalDevices] retain];

    enumerator = [endpoints objectEnumerator];
    while ((midiObject = [enumerator nextObject])) {
        [center addObserver:self selector:@selector(midiObjectChanged:) name:NSNotification.midiObjectPropertyChanged object:midiObject];
    }

    enumerator = [externalDevices objectEnumerator];
    while ((midiObject = [enumerator nextObject])) {
        [center addObserver:self selector:@selector(midiObjectChanged:) name:NSNotification.midiObjectPropertyChanged object:midiObject];
    }
}

- (void)releaseEndpointsAndExternalDevices
{
    [endpoints release];
    endpoints = nil;
    [externalDevices release];
    externalDevices = nil;
}

- (void)midiSetupChanged:(NSNotification *)notification
{
    [self captureEndpointsAndExternalDevices];

    if ([[outlineView window] isVisible]) {
        [outlineView reloadData];
    }
}

- (void)midiObjectChanged:(NSNotification *)notification
{
    NSString* propertyName = [[notification userInfo] objectForKey:MIDIContext.changedProperty];
    if ([propertyName isEqualToString:(NSString *)kMIDIPropertyName]) {
        // invalidate only the row for this object
        NSInteger row = [outlineView rowForItem:[notification object]];
        [outlineView setNeedsDisplayInRect:[outlineView rectOfRow:row]];
    } else if ([propertyName isEqualToString:(NSString *)kMIDIPropertyMaxSysExSpeed]) {
        // invalidate this row and the parent (if any)
        NSInteger row = [outlineView rowForItem:[notification object]];
        [self invalidateRowAndParent:row];
    }
}

- (NSInteger)effectiveSpeedForItem:(MIDIObject*)item
{
    NSInteger effectiveSpeed = (item == trackingMIDIObject) ? speedOfTrackingMIDIObject : [item maxSysExSpeed];

    if ([item isKindOfClass:[Destination class]]) {
        // Return the minimum of this endpoint's speed and all of its external devices' speeds
        NSEnumerator* oe = [[(Destination*)item connectedExternalDevices] objectEnumerator];
        MIDIObject* extDevice;
        while ((extDevice = [oe nextObject])) {
            NSInteger extDeviceSpeed = (extDevice == trackingMIDIObject) ? speedOfTrackingMIDIObject : [extDevice maxSysExSpeed];
            effectiveSpeed = MIN(effectiveSpeed, extDeviceSpeed);
        }
    }
    
    return effectiveSpeed;
}

- (void)invalidateRowAndParent:(NSInteger)row
{
    if (row >= 0) {
        [outlineView setNeedsDisplayInRect:[outlineView rectOfRow:row]];

        NSInteger level = [outlineView levelForRow:row];
        if (level > 0) {
            // walk up rows until we hit one at a higher level -- that will be our parent
            while (row > 0 && [outlineView levelForRow:--row] == level)
                ;   // nothing needs doing
            [outlineView setNeedsDisplayInRect:[outlineView rectOfRow:row]];
        }
    }
}

@end
