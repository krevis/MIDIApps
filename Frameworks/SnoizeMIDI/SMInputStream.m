//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import "SMInputStream.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMessage.h"
#import "SMMessageParser.h"
#import "SMSystemExclusiveMessage.h"


@interface SMInputStream (Private)

static void midiReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);

- (id <SMInputStreamSource>)_findInputSourceWithName:(NSString *)desiredName uniqueID:(NSNumber *)desiredUniqueID;

@end


@implementation SMInputStream

DEFINE_NSSTRING(SMInputStreamReadingSysExNotification);
DEFINE_NSSTRING(SMInputStreamDoneReadingSysExNotification);


- (id)init;
{
    if (!(self = [super init]))
        return nil;

    sysExTimeOut = 1.0;
    
    return self;
}

- (void)dealloc;
{
    [super dealloc];
}

- (id<SMMessageDestination>)messageDestination;
{
    return nonretainedMessageDestination;
}

- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;
{
    nonretainedMessageDestination = messageDestination;
}

- (NSTimeInterval)sysExTimeOut;
{
    return sysExTimeOut;
}

- (void)setSysExTimeOut:(NSTimeInterval)value;
{
    NSArray *parsers;
    unsigned int parserIndex;

    if (sysExTimeOut == value)
        return;

    sysExTimeOut = value;

    parsers = [self parsers];
    parserIndex = [parsers count];
    while (parserIndex--)
        [[parsers objectAtIndex:parserIndex] setSysExTimeOut:sysExTimeOut];
}

- (BOOL)cancelReceivingSysExMessage;
{
    [[self parsers] makeObjectsPerformSelector:@selector(cancelReceivingSysExMessage)];
    // TODO is the return value really used anywhere?  (need to AND or OR the results together?)
    return YES;
}

- (id)persistentSettings;
{
    NSArray *selectedInputSources;
    unsigned int sourcesIndex, sourcesCount;
    NSMutableArray *persistentSettings;

    selectedInputSources = [self selectedInputSources];
    sourcesCount = [selectedInputSources count];
    if (sourcesCount == 0)
        return nil;
    persistentSettings = [NSMutableArray arrayWithCapacity:sourcesCount];

    for (sourcesIndex = 0; sourcesIndex < sourcesCount; sourcesIndex++) {
        id <SMInputStreamSource> source;
        NSMutableDictionary *dict;
        id object;

        source = [selectedInputSources objectAtIndex:sourcesIndex];
        dict = [NSMutableDictionary dictionary];
        if ((object = [source inputStreamSourceUniqueID]))
            [dict setObject:object forKey:@"uniqueID"];
        if ((object = [source inputStreamSourceName]))
            [dict setObject:object forKey:@"name"];

        [persistentSettings addObject:dict];
    }
    
    return persistentSettings;
}

- (NSArray *)takePersistentSettings:(id)settings;
{
    // If any endpoints couldn't be found, their names are returned
    NSArray *settingsArray = (NSArray *)settings;
    unsigned int settingsCount, settingsIndex;
    NSMutableArray *newInputSources;
    NSMutableArray *missingNames = nil;

    settingsCount = [settingsArray count];
    newInputSources = [NSMutableArray arrayWithCapacity:settingsCount];
    for (settingsIndex = 0; settingsIndex < settingsCount; settingsIndex++) {
        NSDictionary *dict;
        NSString *name;
        NSNumber *uniqueID;
        id <SMInputStreamSource> source;

        dict = [settingsArray objectAtIndex:settingsIndex];
        name = [dict objectForKey:@"name"];
        uniqueID = [dict objectForKey:@"uniqueID"];
        if ((source = [self _findInputSourceWithName:name uniqueID:uniqueID])) {
            [newInputSources addObject:source];
        } else {
            if (!name)
                name = NSLocalizedStringFromTableInBundle(@"Unknown", @"SnoizeMIDI", [self bundle], "name of missing endpoint if not specified in document");
            if (!missingNames)
                missingNames = [NSMutableArray array];
            [missingNames addObject:name];
        }
    }

    [self setSelectedInputSources:newInputSources];

    return missingNames;
}

//
// For use by subclasses only
//

- (MIDIReadProc)midiReadProc;
{
    return midiReadProc;
}

- (SMMessageParser *)newParserWithOriginatingEndpoint:(SMEndpoint *)originatingEndpoint;
{
    SMMessageParser *parser;

    parser = [[[SMMessageParser alloc] init] autorelease];
    [parser setDelegate:self];
    [parser setSysExTimeOut:sysExTimeOut];
    [parser setOriginatingEndpoint:originatingEndpoint];

    return parser;
}

//
// For subclasses to implement
//

- (NSArray *)parsers;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (SMMessageParser *)parserForSourceConnectionRefCon:(void *)refCon;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSArray *)inputSources;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSArray *)selectedInputSources;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)setSelectedInputSources:(NSArray *)sources;
{
    OBRequestConcreteImplementation(self, _cmd);
    return;
}

//
// Parser delegate
//

- (void)parser:(SMMessageParser *)parser didReadMessages:(NSArray *)messages;
{
    [nonretainedMessageDestination takeMIDIMessages:messages];
}

- (void)parser:(SMMessageParser *)parser isReadingSysExWithLength:(unsigned int)length;
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:length] forKey:@"length"];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamReadingSysExNotification object:self userInfo:userInfo];
        // TODO There could be multiple sysex messages being read simultaneously (from different sources), but this notification gives no way to distinguish between them.
}

- (void)parser:(SMMessageParser *)parser finishedReadingSysExMessage:(SMSystemExclusiveMessage *)message;
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInt:1 + [[message receivedData] length]], @"length",
        [NSNumber numberWithBool:[message wasReceivedWithEOX]], @"valid", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMInputStreamDoneReadingSysExNotification object:self userInfo:userInfo];
        // TODO There could be multiple sysex messages being read simultaneously (from different sources), but this notification gives no way to distinguish between them.
}

@end


@implementation SMInputStream (Private)

static void midiReadProc(const MIDIPacketList *packetList, void *readProcRefCon, void *srcConnRefCon)
{
    // NOTE: This function is called in a separate, "high-priority" thread.

    SMInputStream *self = (SMInputStream *)readProcRefCon;
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];
    [[self parserForSourceConnectionRefCon:srcConnRefCon] takePacketList:packetList];
    [pool release];
}

- (id <SMInputStreamSource>)_findInputSourceWithName:(NSString *)desiredName uniqueID:(NSNumber *)desiredUniqueID;
{
    // Find the input source with the desired unique ID. If there are no matches by uniqueID, return the first source whose name matches.
    // Otherwise, return nil.

    NSArray *inputSources;
    unsigned int inputSourceCount, inputSourceIndex;
    id <SMInputStreamSource> sourceWithMatchingName = nil;

    inputSources = [self inputSources];
    inputSourceCount = [inputSources count];
    for (inputSourceIndex = 0; inputSourceIndex < inputSourceCount; inputSourceIndex++) {
        id <SMInputStreamSource> source;

        source = [inputSources objectAtIndex:inputSourceIndex];
        if ([[source inputStreamSourceUniqueID] isEqual:desiredUniqueID])
            return source;
        else if (!sourceWithMatchingName && [[source inputStreamSourceName] isEqualToString:desiredName])
            sourceWithMatchingName = source;
    }

    return sourceWithMatchingName;
}

@end
