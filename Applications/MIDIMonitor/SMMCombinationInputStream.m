//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMMCombinationInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SMMAppController.h"
#import "SMMSpyingInputStream.h"


@interface SMMCombinationInputStream (Private)

- (void)_observeNotificationsWithCenter:(NSNotificationCenter *)center object:(id)object;

- (void)_repostNotification:(NSNotification *)notification;

- (NSArray *)_objectsFromArray:(NSArray *)array1 inArray:(NSArray *)array2;

- (void)_makeInputStream:(SMInputStream *)stream takePersistentSettings:(id)settings addingMissingNamesToArray:(NSMutableArray *)missingNames;

@end



@implementation SMMCombinationInputStream

- (id)init;
{
    NSNotificationCenter *center;
    MIDISpyClientRef spyClient; 
    
    if (!(self = [super init]))
        return nil;

    center = [NSNotificationCenter defaultCenter];
    
    portInputStream = [[SMPortInputStream alloc] init];
    [portInputStream setMessageDestination:self];
    [self _observeNotificationsWithCenter:center object:portInputStream];

    virtualInputStream = [[SMVirtualInputStream alloc] init];
    [virtualInputStream setMessageDestination:self];
    [self _observeNotificationsWithCenter:center object:virtualInputStream];
    [virtualInputStream setInputSourceName:NSLocalizedStringFromTableInBundle(@"Act as a destination for other programs", @"MIDIMonitor", [self bundle], "title of popup menu item for virtual destination")];

    if ((spyClient = [[NSApp delegate] midiSpyClient])) {
        spyingInputStream = [[SMMSpyingInputStream alloc] initWithMIDISpyClient:spyClient];
        if (spyingInputStream) {
            [spyingInputStream setMessageDestination:self];
            [self _observeNotificationsWithCenter:center object:spyingInputStream];        
        }
    }

    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [portInputStream release];
    portInputStream = nil;

    [virtualInputStream release];
    virtualInputStream = nil;

    [spyingInputStream release];
    spyingInputStream = nil;
    
    [super dealloc];
}

// SMMessageDestination protocol implementation

- (void)takeMIDIMessages:(NSArray *)messages;
{
    [nonretainedMessageDestination takeMIDIMessages:messages];
}

// Other methods

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;
{
    nonretainedMessageDestination = messageDestination;
}

- (NSArray *)groupedInputSources;
{
    NSMutableArray *groupedInputSources;

    groupedInputSources = [NSMutableArray array];

    [groupedInputSources addObject:[portInputStream inputSources]];
    [groupedInputSources addObject:[virtualInputStream inputSources]];
    if (spyingInputStream)
        [groupedInputSources addObject:[spyingInputStream inputSources]];

    // TODO It might be nice to cache this... see if it makes any difference really.

    return groupedInputSources;
}

- (NSArray *)selectedInputSources;
{
    NSMutableArray *inputSources;

    inputSources = [NSMutableArray array];

    [inputSources addObjectsFromArray:[portInputStream selectedInputSources]];
    [inputSources addObjectsFromArray:[virtualInputStream selectedInputSources]];
    if (spyingInputStream)
        [inputSources addObjectsFromArray:[spyingInputStream selectedInputSources]];

    return inputSources;
}

- (void)setSelectedInputSources:(NSArray *)inputSources;
{
    [portInputStream setSelectedInputSources:[self _objectsFromArray:inputSources inArray:[portInputStream inputSources]]];
    [virtualInputStream setSelectedInputSources:[self _objectsFromArray:inputSources inArray:[virtualInputStream inputSources]]];
    if (spyingInputStream)
        [spyingInputStream setSelectedInputSources:[self _objectsFromArray:inputSources inArray:[spyingInputStream inputSources]]];
}

- (NSDictionary *)persistentSettings;
{
    NSMutableDictionary *persistentSettings;
    id streamSettings;

    persistentSettings = [NSMutableDictionary dictionary];

    if ((streamSettings = [portInputStream persistentSettings]))
        [persistentSettings setObject:streamSettings forKey:@"portInputStream"];
    if ((streamSettings = [virtualInputStream persistentSettings]))
        [persistentSettings setObject:streamSettings forKey:@"virtualInputStream"];
    if ((streamSettings = [spyingInputStream persistentSettings]))
        [persistentSettings setObject:streamSettings forKey:@"spyingInputStream"];

    if ([persistentSettings count] > 0)
        return persistentSettings;
    else
        return nil;
}

- (NSArray *)takePersistentSettings:(NSDictionary *)settings;
{
    // If any endpoints couldn't be found, their names are returned
    NSMutableArray *missingNames;
    NSNumber *oldStyleUniqueID;

    missingNames = [NSMutableArray array];

    // Clear out the current input sources
    [self setSelectedInputSources:[NSArray array]];

    if ((oldStyleUniqueID = [settings objectForKey:@"portEndpointUniqueID"])) {
        // This is an old-style document, specifiying an endpoint for the port input stream.
        // We may have an endpoint name under key @"portEndpointName"
        NSString *sourceEndpointName;
        SMSourceEndpoint *sourceEndpoint;

        sourceEndpointName = [settings objectForKey:@"portEndpointName"];
        
        sourceEndpoint = [SMSourceEndpoint sourceEndpointWithUniqueID:[oldStyleUniqueID intValue]];
        if (!sourceEndpoint && sourceEndpointName)
            sourceEndpoint = [SMSourceEndpoint sourceEndpointWithName:sourceEndpointName];

        if (sourceEndpoint) {
            [portInputStream addEndpoint:sourceEndpoint];
        } else {
            if (!sourceEndpointName)
                sourceEndpointName = NSLocalizedStringFromTableInBundle(@"Unknown", @"MIDIMonitor", [self bundle], "name of missing endpoint if not specified in document");
            [missingNames addObject:sourceEndpointName];
        }
        
    } else if ((oldStyleUniqueID = [settings objectForKey:@"virtualEndpointUniqueID"])) {
        // This is an old-style document, specifiying to use a virtual input stream.
        [virtualInputStream setUniqueID:[oldStyleUniqueID intValue]];
        [virtualInputStream setSelectedInputSources:[virtualInputStream inputSources]];

    } else {
        // This is a current-style document        
        [self _makeInputStream:portInputStream takePersistentSettings:[settings objectForKey:@"portInputStream"] addingMissingNamesToArray:missingNames];
        [self _makeInputStream:virtualInputStream takePersistentSettings:[settings objectForKey:@"virtualInputStream"] addingMissingNamesToArray:missingNames];
        if (spyingInputStream)
            [self _makeInputStream:spyingInputStream takePersistentSettings:[settings objectForKey:@"spyingInputStream"] addingMissingNamesToArray:missingNames];
    }
    
    if ([missingNames count] > 0)
        return missingNames;
    else
        return nil;
}

- (NSString *)virtualEndpointName;
{
    return [virtualInputStream virtualEndpointName];
}

- (void)setVirtualEndpointName:(NSString *)value;
{
    [virtualInputStream setVirtualEndpointName:value];
}

@end


@implementation SMMCombinationInputStream (Private)

- (void)_observeNotificationsWithCenter:(NSNotificationCenter *)center object:(id)object;
{
    [center addObserver:self selector:@selector(_repostNotification:) name:SMInputStreamReadingSysExNotification object:object];
    [center addObserver:self selector:@selector(_repostNotification:) name:SMInputStreamDoneReadingSysExNotification object:object];
    [center addObserver:self selector:@selector(_repostNotification:) name:SMInputStreamSelectedInputSourceDisappearedNotification object:object];
}

- (void)_repostNotification:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self userInfo:[notification userInfo]];
}

- (NSArray *)_objectsFromArray:(NSArray *)array1 inArray:(NSArray *)array2;
{
    NSMutableSet *set;

    set = [NSMutableSet setWithArray:array1];
    [set intersectSet:[NSSet setWithArray:array2]];
    return [set allObjects];    
}

- (void)_makeInputStream:(SMInputStream *)stream takePersistentSettings:(id)settings addingMissingNamesToArray:(NSMutableArray *)missingNames;
{
    NSArray *streamMissingNames;

    if (!settings)
        return;

    streamMissingNames = [stream takePersistentSettings:settings];
    if (streamMissingNames)
        [missingNames addObjectsFromArray:streamMissingNames];
}

@end
