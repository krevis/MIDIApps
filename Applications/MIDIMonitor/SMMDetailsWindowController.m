#import "SMMDetailsWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMPreferencesWindowController.h"
#import "SMMSysExWindowController.h"


@interface SMMDetailsWindowController (Private)

+ (Class)subclassForMessage:(SMMessage *)inMessage;

- (void)displayPreferencesDidChange:(NSNotification *)notification;

- (void)synchronizeDescriptionFields;

- (NSString *)formatData:(NSData *)data;

@end


@implementation SMMDetailsWindowController

static NSMapTable* messageToControllerMapTable = NULL;


+ (BOOL)canShowDetailsForMessage:(SMMessage *)inMessage
{
    return ([self subclassForMessage:inMessage] != Nil);
}

+ (SMMDetailsWindowController *)detailsWindowControllerWithMessage:(SMMessage *)inMessage
{
    SMMDetailsWindowController *controller;

    if (!messageToControllerMapTable) {
        messageToControllerMapTable = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0);
    }

    controller = NSMapGet(messageToControllerMapTable, inMessage);
    if (!controller) {
        controller = [[[self subclassForMessage:inMessage] alloc] initWithMessage:inMessage];
        if (controller) {
            NSMapInsertKnownAbsent(messageToControllerMapTable, inMessage, controller);
            [controller release];            
        }
    }

    return controller;
}

- (id)initWithMessage:(SMMessage *)inMessage;
{
    if (!(self = [super initWithWindowNibName:[[self class] windowNibName]]))
        return nil;

    message = [inMessage retain];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayPreferencesDidChange:) name:SMMDisplayPreferenceChangedNotification object:nil];
    
    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [message release];
    message = nil;
    
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self synchronizeDescriptionFields];

    [textView setString:[self formatData:[self dataForDisplay]]];
}

- (SMMessage *)message;
{
    return message;
}

//
// To be overridden by subclasses
//

+ (NSString *)windowNibName
{
    return @"Details";
}

- (NSData *)dataForDisplay;
{
    return [message otherData];
}

@end


@implementation SMMDetailsWindowController (NotificationsDelegatesDataSources)

- (void)windowWillClose:(NSNotification *)notification;
{
    [[self retain] autorelease];
    NSMapRemove(messageToControllerMapTable, self);
}

@end


@implementation SMMDetailsWindowController (Private)

+ (Class)subclassForMessage:(SMMessage *)inMessage
{
    if ([inMessage isKindOfClass:[SMInvalidMessage class]])
        return [SMMDetailsWindowController class];
    else if ([inMessage isKindOfClass:[SMSystemExclusiveMessage class]])
        return [SMMSysExWindowController class];
    else
        return Nil;
}

- (void)displayPreferencesDidChange:(NSNotification *)notification;
{
    [self synchronizeDescriptionFields];
}

- (void)synchronizeDescriptionFields;
{
    NSString *sizeString = [NSString stringWithFormat:
        NSLocalizedStringFromTableInBundle(@"%@ bytes", @"MIDIMonitor", SMBundleForObject(self), "Details size format string"),
        [SMMessage formatLength:[[self dataForDisplay] length]]];

    [sizeField setStringValue:sizeString];

    [timeField setStringValue:[message timeStampForDisplay]];
}

- (NSString *)formatData:(NSData *)data;
{
    unsigned int dataLength;
    const unsigned char *bytes;
    NSMutableString *formattedString;
    unsigned int dataIndex;
    int lengthDigitCount;
    unsigned int scratchLength;

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
        unsigned int index;
        NSString *lineString;

        // This C stuff may be a little ugly but it is a hell of a lot faster than doing it with NSStrings...

        p = lineBuffer;
        p += sprintf(p, "%.*X", lengthDigitCount, dataIndex);
        
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

        lineString = [[NSString alloc] initWithCString:lineBuffer];
        [formattedString appendString:lineString];
        [lineString release];
    }

    return formattedString;
}

@end
