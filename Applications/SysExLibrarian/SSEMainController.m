//
//  SSEMainController.m
//  SysExLibrarian
//
//  Created by Kurt Revis on Mon Dec 31 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "SSEMainController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSEMainWindowController.h"


@interface SSEMainController (Private)

- (void)_midiSetupDidChange:(NSNotification *)notification;

- (void)_inputStreamEndpointWasRemoved:(NSNotification *)notification;

- (void)_selectFirstAvailableSource;

- (void)_readingSysEx:(NSNotification *)notification;
- (void)_mainThreadReadingSysEx;

- (void)_doneReadingSysEx:(NSNotification *)notification;
- (void)_mainThreadDoneReadingSysEx;

@end


@implementation SSEMainController

- (id)init
{
    NSNotificationCenter *center;

    if (!(self = [super init]))
        return nil;

    center = [NSNotificationCenter defaultCenter];

    inputStream = [[SMPortOrVirtualInputStream alloc] init];
    [center addObserver:self selector:@selector(_inputStreamEndpointWasRemoved:) name:SMPortOrVirtualInputStreamEndpointWasRemoved object:inputStream];
    [center addObserver:self selector:@selector(_readingSysEx:) name:SMInputStreamReadingSysExNotification object:inputStream];
    [center addObserver:self selector:@selector(_doneReadingSysEx:) name:SMInputStreamDoneReadingSysExNotification object:inputStream];
    [inputStream setVirtualDisplayName:NSLocalizedStringFromTableInBundle(@"Act as a destination for other programs", @"SysExLibrarian", [self bundle], "title of popup menu item for virtual destination")];
    [inputStream setVirtualEndpointName:@"SysEx Librarian"];	// TODO get this from somewhere
    [inputStream setMessageDestination:self];

    listenToMIDISetupChanges = YES;
    sysExBytesRead = 0;

    [center addObserver:self selector:@selector(_midiSetupDidChange:) name:SMClientSetupChangedNotification object:[SMClient sharedClient]];

    // TODO should get selected source and dest from preferences
    [self _selectFirstAvailableSource];
//    [self _selectFirstAvailableDestination];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [inputStream release];
    inputStream = nil;

    [super dealloc];
}

//
// API for SSEMainWindowController
//

- (NSArray *)sourceDescriptions;
{
    return [inputStream sourceDescriptions];
}

- (NSDictionary *)sourceDescription;
{
    return [inputStream sourceDescription];
}

- (void)setSourceDescription:(NSDictionary *)description;
{
    NSDictionary *oldDescription;
    BOOL savedListenFlag;

    oldDescription = [self sourceDescription];
    if (oldDescription == description || [oldDescription isEqual:description])
        return;

    savedListenFlag = listenToMIDISetupChanges;
    listenToMIDISetupChanges = NO;

    [inputStream setSourceDescription:description];
    // TODO we don't have an undo manager yet
//    [[[self undoManager] prepareWithInvocationTarget:self] setSourceDescription:oldDescription];
//    [[self undoManager] setActionName:NSLocalizedStringFromTableInBundle(@"Change Source", @"SysExLibrarian", [self bundle], "change source undo action")];

    listenToMIDISetupChanges = savedListenFlag;

    [windowController synchronizeSources];
}

//
// SMMessageDestination protocol
//

- (void)takeMIDIMessages:(NSArray *)messages;
{
    // TODO handle sysex messages, ignore all others
}

@end


@implementation SSEMainController (Private)

- (void)_midiSetupDidChange:(NSNotification *)notification;
{
    if (listenToMIDISetupChanges)
        [windowController synchronizeSources];
    // TODO synchronize dests too
}

- (void)_inputStreamEndpointWasRemoved:(NSNotification *)notification;
{
    // TODO should print a message?
    [self _selectFirstAvailableSource];
}

- (void)_selectFirstAvailableSource;
{
    NSArray *descriptions;

    descriptions = [inputStream sourceDescriptions];
    if ([descriptions count] > 0)
        [inputStream setSourceDescription:[descriptions objectAtIndex:0]];
}

- (void)_readingSysEx:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread

    sysExBytesRead = [[[notification userInfo] objectForKey:@"length"] unsignedIntValue];
    [self queueSelectorOnce:@selector(_mainThreadReadingSysEx)];
    // We don't mind if this gets coalesced
}

- (void)_mainThreadReadingSysEx;
{
//    [windowController updateSysExReadIndicatorWithBytes:sysExBytesRead];
}

- (void)_doneReadingSysEx:(NSNotification *)notification;
{
    // NOTE This is happening in the MIDI thread
    NSNumber *number;

    number = [[notification userInfo] objectForKey:@"length"];
    sysExBytesRead = [number unsignedIntValue];
    [self queueSelector:@selector(_mainThreadDoneReadingSysEx)];
    // We DO mind if this gets coalesced, so always queue it
}

- (void)_mainThreadDoneReadingSysEx;
{
//    [windowController stopSysExReadIndicatorWithBytes:sysExBytesRead];
}

@end
