//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMMCombinationInputStream.h"

#import "SMMSpyingInputStream.h"

@interface SMMCombinationInputStream (Private)

- (void)_observeSysExNotificationsWithCenter:(NSNotificationCenter *)center object:(id)object;

- (void)_repostNotification:(NSNotification *)notification;

- (NSArray *)_objectsFromArray:(NSArray *)array1 inArray:(NSArray *)array2;

@end



@implementation SMMCombinationInputStream

- (id)init;
{
    NSNotificationCenter *center;
    
    if (!(self = [super init]))
        return nil;

    center = [NSNotificationCenter defaultCenter];
    
    portInputStream = [[SMPortInputStream alloc] init];
    [portInputStream setMessageDestination:self];
    [center addObserver:self selector:@selector(_repostNotification:) name:SMPortInputStreamEndpointDisappeared object:portInputStream];
    [self _observeSysExNotificationsWithCenter:center object:portInputStream];

    virtualInputStream = [[SMVirtualInputStream alloc] init];
    [virtualInputStream setMessageDestination:self];
    [self _observeSysExNotificationsWithCenter:center object:virtualInputStream];

    spyingInputStream = [[SMMSpyingInputStream alloc] init];
    [spyingInputStream setMessageDestination:self];
    [self _observeSysExNotificationsWithCenter:center object:spyingInputStream];

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
    [inputSources addObjectsFromArray:[spyingInputStream selectedInputSources]];

    return inputSources;
}

- (void)setSelectedInputSources:(NSArray *)inputSources;
{
    [portInputStream setSelectedInputSources:[self _objectsFromArray:inputSources inArray:[portInputStream inputSources]]];
    [virtualInputStream setSelectedInputSources:[self _objectsFromArray:inputSources inArray:[virtualInputStream inputSources]]];
    [spyingInputStream setSelectedInputSources:[self _objectsFromArray:inputSources inArray:[spyingInputStream inputSources]]];
}

- (NSDictionary *)persistentSettings;
{
    // TODO
    return nil;
}

- (NSArray *)takePersistentSettings:(NSDictionary *)settings;
{
    // If any endpoints couldn't be found, their names are returned
    // TODO
    return nil;
}

@end


@implementation SMMCombinationInputStream (Private)

- (void)_observeSysExNotificationsWithCenter:(NSNotificationCenter *)center object:(id)object;
{
    [center addObserver:self selector:@selector(_repostNotification:) name:SMInputStreamReadingSysExNotification object:object];
    [center addObserver:self selector:@selector(_repostNotification:) name:SMInputStreamDoneReadingSysExNotification object:object];
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

@end
