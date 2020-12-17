/*
 Copyright (c) 2002-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

@import Cocoa;

#import "SMMCombinationInputStream.h"

#import "MIDI_Monitor-Swift.h"
#import "SMMSpyingInputStream.h"

@interface SMMCombinationInputStream ()
{
    NSArray *_groupedInputSources;
}

@property (nonatomic, retain) SMPortInputStream *portInputStream;
@property (nonatomic, retain) SMVirtualInputStream *virtualInputStream;
@property (nonatomic, retain) SMMSpyingInputStream *spyingInputStream;

@property (nonatomic, assign) BOOL willPostSourceListChangedNotification;

@end

@implementation SMMCombinationInputStream

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;

    @try {
        _portInputStream = [[SMPortInputStream alloc] init];
    }
    @catch (id ignored) {
        _portInputStream = nil;
    }
    if (_portInputStream) {
        _portInputStream.messageDestination = self;
        [self observeNotificationsFromObject:_portInputStream];
    }

    _virtualInputStream = [[SMVirtualInputStream alloc] init];
    if (_virtualInputStream) {
        _virtualInputStream.messageDestination = self;
        [self observeNotificationsFromObject:_virtualInputStream];
    }

    // TODO Work this out
    MIDISpyClientRef spyClient = nil; // [(SMMAppController *)[NSApp delegate] midiSpyClient];
    if (spyClient) {
        _spyingInputStream = [[SMMSpyingInputStream alloc] initWithMIDISpyClient:spyClient];
        if (_spyingInputStream) {
            _spyingInputStream.messageDestination = self;
            [self observeNotificationsFromObject:_spyingInputStream];
        }
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_groupedInputSources release];
    _groupedInputSources = nil;
    
    _portInputStream.messageDestination = nil;
    [_portInputStream release];
    _portInputStream = nil;

    _virtualInputStream.messageDestination = nil;
    [_virtualInputStream release];
    _virtualInputStream = nil;

    _spyingInputStream.messageDestination = nil;
    [_spyingInputStream release];
    _spyingInputStream = nil;
    
    [super dealloc];
}

// SMMessageDestination protocol implementation

- (void)takeMIDIMessages:(NSArray *)messages
{
    [self.messageDestination takeMIDIMessages:messages];
}

// Other methods

- (NSArray *)groupedInputSources
{
    if (!_groupedInputSources) {
        NSString *groupName = NSLocalizedStringFromTableInBundle(@"MIDI sources", @"MIDIMonitor", SMBundleForObject(self), "name of group for ordinary sources");
        NSDictionary *portGroup = [NSMutableDictionary dictionaryWithObjectsAndKeys:groupName, @"name", nil];

        groupName = NSLocalizedStringFromTableInBundle(@"Act as a destination for other programs", @"MIDIMonitor", SMBundleForObject(self), "name of source item for virtual destination");
        NSDictionary *virtualGroup = [NSMutableDictionary dictionaryWithObjectsAndKeys:groupName, @"name", @(YES), @"isNotExpandable", nil];

        NSDictionary *spyingGroup = nil;
        if (self.spyingInputStream) {
            groupName = NSLocalizedStringFromTableInBundle(@"Spy on output to destinations", @"MIDIMonitor", SMBundleForObject(self), "name of group for spying on destinations");
            spyingGroup = [NSMutableDictionary dictionaryWithObjectsAndKeys:groupName, @"name", nil];
        }

        _groupedInputSources = [[NSArray alloc] initWithObjects:portGroup, virtualGroup, spyingGroup, nil];
    }

    if (self.portInputStream) {
        _groupedInputSources[0][@"sources"] = self.portInputStream.inputSources;
    }
    _groupedInputSources[1][@"sources"] = self.virtualInputStream.inputSources;
    if (self.spyingInputStream) {
        _groupedInputSources[2][@"sources"] = self.spyingInputStream.inputSources;
    }

    return _groupedInputSources;
}

- (NSSet *)selectedInputSources
{
    NSMutableSet *inputSources = [NSMutableSet set];

    if (self.portInputStream) {
        [inputSources unionSet:self.portInputStream.selectedInputSources];
    }
    [inputSources unionSet:self.virtualInputStream.selectedInputSources];
    if (self.spyingInputStream) {
        [inputSources unionSet:self.spyingInputStream.selectedInputSources];
    }

    return inputSources;
}

- (void)setSelectedInputSources:(NSSet *)inputSources
{
    if (!inputSources) {
        inputSources = [NSSet set];
    }

    if (self.portInputStream) {
        self.portInputStream.selectedInputSources = [self intersectionOfSet:inputSources andArray:self.portInputStream.inputSources];
    }
    self.virtualInputStream.selectedInputSources = [self intersectionOfSet:inputSources andArray:self.virtualInputStream.inputSources];
    if (self.spyingInputStream) {
        self.spyingInputStream.selectedInputSources = [self intersectionOfSet:inputSources andArray:self.spyingInputStream.inputSources];
    }
}

- (NSDictionary *)persistentSettings
{
    NSMutableDictionary* persistentSettings = [NSMutableDictionary dictionary];
    id streamSettings;

    if ((streamSettings = self.portInputStream.persistentSettings)) {
        persistentSettings[@"portInputStream"] = streamSettings;
    }
    if ((streamSettings = self.virtualInputStream.persistentSettings)) {
        persistentSettings[@"virtualInputStream"] = streamSettings;
    }
    if ((streamSettings = self.spyingInputStream.persistentSettings)) {
        persistentSettings[@"spyingInputStream"] = streamSettings;
    }

    return (persistentSettings.count > 0) ? persistentSettings : nil;
}

- (NSArray *)takePersistentSettings:(NSDictionary *)settings
{
    // If any endpoints couldn't be found, their names are returned
    NSMutableArray *missingNames = [NSMutableArray array];
    NSNumber *oldStyleUniqueID;

    // Clear out the current input sources
    self.selectedInputSources = [NSSet set];

    if ((oldStyleUniqueID = settings[@"portEndpointUniqueID"])) {
        // This is an old-style document, specifiying an endpoint for the port input stream.
        // We may have an endpoint name under key @"portEndpointName"

        NSString *sourceEndpointName = settings[@"portEndpointName"];
        
        SMSourceEndpoint *sourceEndpoint = [SMSourceEndpoint sourceEndpointWithUniqueID:[oldStyleUniqueID intValue]];
        if (!sourceEndpoint && sourceEndpointName) {
            sourceEndpoint = [SMSourceEndpoint sourceEndpointWithName:sourceEndpointName];
        }

        if (sourceEndpoint) {
            [self.portInputStream addEndpoint:sourceEndpoint];
        } else {
            if (!sourceEndpointName) {
                sourceEndpointName = NSLocalizedStringFromTableInBundle(@"Unknown", @"MIDIMonitor", SMBundleForObject(self), "name of missing endpoint if not specified in document");
            }
            [missingNames addObject:sourceEndpointName];
        }
        
    } else if ((oldStyleUniqueID = settings[@"virtualEndpointUniqueID"])) {
        // This is an old-style document, specifiying to use a virtual input stream.
        self.virtualInputStream.uniqueID = [oldStyleUniqueID intValue];
        self.virtualInputStream.selectedInputSources = [NSSet setWithArray:self.virtualInputStream.inputSources];
    } else {
        // This is a current-style document        
        [self makeInputStream:self.portInputStream takePersistentSettings:settings[@"portInputStream"] addingMissingNamesToArray:missingNames];
        [self makeInputStream:self.virtualInputStream takePersistentSettings:settings[@"virtualInputStream"] addingMissingNamesToArray:missingNames];
        if (self.spyingInputStream) {
            [self makeInputStream:self.spyingInputStream takePersistentSettings:settings[@"spyingInputStream"] addingMissingNamesToArray:missingNames];
        }
    }
    
    return (missingNames.count > 0) ? missingNames : nil;
}

- (NSString *)virtualEndpointName
{
    return self.virtualInputStream.virtualEndpointName;
}

- (void)setVirtualEndpointName:(NSString *)value
{
    self.virtualInputStream.virtualEndpointName = value;
}


#pragma mark Private

- (void)observeNotificationsFromObject:(id)object
{
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(repostNotification:) name:SMInputStreamReadingSysExNotification object:object];
    [center addObserver:self selector:@selector(repostNotification:) name:SMInputStreamDoneReadingSysExNotification object:object];
    [center addObserver:self selector:@selector(repostNotification:) name:SMInputStreamSelectedInputSourceDisappearedNotification object:object];
    [center addObserver:self selector:@selector(inputSourceListChanged:) name:SMInputStreamSourceListChangedNotification object:object];
}

- (void)repostNotification:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:notification.name object:self userInfo:notification.userInfo];
}

- (void)inputSourceListChanged:(NSNotification *)notification
{
    // We may get this notification from more than one of our streams, so coalesce all the notifications from all of the streams into one notification from us.

    if (!self.willPostSourceListChangedNotification) {
        self.willPostSourceListChangedNotification = YES;
        [self retain];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.willPostSourceListChangedNotification = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:notification.name object:self];
            [self autorelease];
        });
    }
}

- (NSSet *)intersectionOfSet:(NSSet *)set1 andArray:(NSArray *)array2
{
    NSMutableSet *set2 = [NSMutableSet setWithArray:array2];
    [set2 intersectSet:set1];
    return set2;
}

- (void)makeInputStream:(SMInputStream *)stream takePersistentSettings:(id)settings addingMissingNamesToArray:(NSMutableArray *)missingNames
{
    if (settings) {
        NSArray *streamMissingNames = [stream takePersistentSettings:settings];
        if (streamMissingNames) {
            [missingNames addObjectsFromArray:streamMissingNames];
        }
    }
}

@end
