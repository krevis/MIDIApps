//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMMCombinationInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SMMAppController.h"
#import "SMMSpyingInputStream.h"


@interface SMMCombinationInputStream (Private)

- (void)observeNotificationsWithCenter:(NSNotificationCenter *)center object:(id)object;

- (void)repostNotification:(NSNotification *)notification;
- (void)inputSourceListChanged:(NSNotification *)notification;

- (NSSet *)intersectionOfSet:(NSSet *)set1 andArray:(NSArray *)array2;

- (void)makeInputStream:(SMInputStream *)stream takePersistentSettings:(id)settings addingMissingNamesToArray:(NSMutableArray *)missingNames;

@end



@implementation SMMCombinationInputStream

- (id)init;
{
    NSNotificationCenter *center;
    MIDISpyClientRef spyClient; 
    
    if (!(self = [super init]))
        return nil;

    center = [NSNotificationCenter defaultCenter];

    NS_DURING {
        portInputStream = [[SMPortInputStream alloc] init];
    } NS_HANDLER {
        portInputStream = nil;
    } NS_ENDHANDLER;
    if (portInputStream) {
        [portInputStream setMessageDestination:self];
        [self observeNotificationsWithCenter:center object:portInputStream];
    }

    virtualInputStream = [[SMVirtualInputStream alloc] init];
    [virtualInputStream setMessageDestination:self];
    [self observeNotificationsWithCenter:center object:virtualInputStream];

    if ((spyClient = [[NSApp delegate] midiSpyClient])) {
        spyingInputStream = [[SMMSpyingInputStream alloc] initWithMIDISpyClient:spyClient];
        if (spyingInputStream) {
            [spyingInputStream setMessageDestination:self];
            [self observeNotificationsWithCenter:center object:spyingInputStream];        
        }
    }

    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [groupedInputSources release];
    groupedInputSources = nil;
    
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
    if (!groupedInputSources) {
        NSDictionary *portGroup, *virtualGroup, *spyingGroup;
        NSString *groupName;

        groupName = NSLocalizedStringFromTableInBundle(@"MIDI sources", @"MIDIMonitor", [self bundle], "name of group for ordinary sources");
        portGroup = [NSMutableDictionary dictionaryWithObjectsAndKeys:groupName, @"name", nil];

        groupName = NSLocalizedStringFromTableInBundle(@"Act as a destination for other programs", @"MIDIMonitor", [self bundle], "name of source item for virtual destination");
        virtualGroup = [NSMutableDictionary dictionaryWithObjectsAndKeys:groupName, @"name", [NSNumber numberWithBool:YES], @"isNotExpandable", nil];

        if (spyingInputStream) {
            groupName = NSLocalizedStringFromTableInBundle(@"Spy on output to destinations", @"MIDIMonitor", [self bundle], "name of group for spying on destinations");
            spyingGroup = [NSMutableDictionary dictionaryWithObjectsAndKeys:groupName, @"name", nil];
        } else {
            spyingGroup = nil;
        }

        groupedInputSources = [[NSArray alloc] initWithObjects:portGroup, virtualGroup, spyingGroup, nil];
    }

    if (portInputStream)
        [[groupedInputSources objectAtIndex:0] setObject:[portInputStream inputSources] forKey:@"sources"];
    [[groupedInputSources objectAtIndex:1] setObject:[virtualInputStream inputSources] forKey:@"sources"];
    if (spyingInputStream)
        [[groupedInputSources objectAtIndex:2] setObject:[spyingInputStream inputSources] forKey:@"sources"];

    return groupedInputSources;
}

- (NSSet *)selectedInputSources;
{
    NSMutableSet *inputSources;

    inputSources = [NSMutableSet set];

    if (portInputStream)
        [inputSources unionSet:[portInputStream selectedInputSources]];
    [inputSources unionSet:[virtualInputStream selectedInputSources]];
    if (spyingInputStream)
        [inputSources unionSet:[spyingInputStream selectedInputSources]];

    return inputSources;
}

- (void)setSelectedInputSources:(NSSet *)inputSources;
{
    if (!inputSources)
        inputSources = [NSSet set];

    if (portInputStream)
        [portInputStream setSelectedInputSources:[self intersectionOfSet:inputSources andArray:[portInputStream inputSources]]];
    [virtualInputStream setSelectedInputSources:[self intersectionOfSet:inputSources andArray:[virtualInputStream inputSources]]];
    if (spyingInputStream)
        [spyingInputStream setSelectedInputSources:[self intersectionOfSet:inputSources andArray:[spyingInputStream inputSources]]];
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
    [self setSelectedInputSources:[NSSet set]];

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
        [virtualInputStream setSelectedInputSources:[NSSet setWithArray:[virtualInputStream inputSources]]];

    } else {
        // This is a current-style document        
        [self makeInputStream:portInputStream takePersistentSettings:[settings objectForKey:@"portInputStream"] addingMissingNamesToArray:missingNames];
        [self makeInputStream:virtualInputStream takePersistentSettings:[settings objectForKey:@"virtualInputStream"] addingMissingNamesToArray:missingNames];
        if (spyingInputStream)
            [self makeInputStream:spyingInputStream takePersistentSettings:[settings objectForKey:@"spyingInputStream"] addingMissingNamesToArray:missingNames];
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

- (void)observeNotificationsWithCenter:(NSNotificationCenter *)center object:(id)object;
{
    [center addObserver:self selector:@selector(repostNotification:) name:SMInputStreamReadingSysExNotification object:object];
    [center addObserver:self selector:@selector(repostNotification:) name:SMInputStreamDoneReadingSysExNotification object:object];
    [center addObserver:self selector:@selector(repostNotification:) name:SMInputStreamSelectedInputSourceDisappearedNotification object:object];
    [center addObserver:self selector:@selector(inputSourceListChanged:) name:SMInputStreamSourceListChangedNotification object:object];
}

- (void)repostNotification:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:[notification name] object:self userInfo:[notification userInfo]];
}

- (void)inputSourceListChanged:(NSNotification *)notification;
{
    // We may get this notification from more than one of our streams, so create our own notification and queue it with coalescing.
    // This way we coalesce all the notifications from all of the streams into one notification from us.
    NSNotification *newNotification;

    newNotification = [NSNotification notificationWithName:SMInputStreamSourceListChangedNotification object:self];

    [[NSNotificationQueue defaultQueue] enqueueNotification:newNotification postingStyle:NSPostWhenIdle coalesceMask:(NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender) forModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

- (NSSet *)intersectionOfSet:(NSSet *)set1 andArray:(NSArray *)array2;
{
    NSMutableSet *set2;

    set2 = [NSMutableSet setWithArray:array2];
    [set2 intersectSet:set1];
    return set2;
}

- (void)makeInputStream:(SMInputStream *)stream takePersistentSettings:(id)settings addingMissingNamesToArray:(NSMutableArray *)missingNames;
{
    NSArray *streamMissingNames;

    if (!settings)
        return;

    streamMissingNames = [stream takePersistentSettings:settings];
    if (streamMissingNames)
        [missingNames addObjectsFromArray:streamMissingNames];
}

@end
