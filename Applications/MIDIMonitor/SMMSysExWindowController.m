#import "SMMSysExWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMPreferencesWindowController.h"


@interface SMMSysExWindowController (Private)

- (void)displayPreferencesDidChange:(NSNotification *)notification;

- (void)synchronizeDescriptionFields;

- (NSString *)formatSysExData:(NSData *)data;

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SMMSysExWindowController

NSString *SMMSaveSysExWithEOXAlwaysPreferenceKey = @"SMMSaveSysExWithEOXAlways";


static NSMutableArray *controllers = nil;

+ (SMMSysExWindowController *)sysExWindowControllerWithMessage:(SMSystemExclusiveMessage *)inMessage;
{
    unsigned int controllerIndex;
    SMMSysExWindowController *controller;

    if (!controllers) {
        controllers = [[NSMutableArray alloc] init];
    }

    controllerIndex = [controllers count];
    while (controllerIndex--) {
        controller = [controllers objectAtIndex:controllerIndex];
        if ([controller message] == inMessage)
            return controller;
    }

    controller = [[SMMSysExWindowController alloc] initWithMessage:inMessage];
    [controllers addObject:controller];
    [controller release];

    return controller;
}

- (id)initWithMessage:(SMSystemExclusiveMessage *)inMessage;
{
    if (!(self = [super initWithWindowNibName:@"SysEx"]))
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

    [textView setString:[self formatSysExData:[message receivedDataWithStartByte]]];
}

- (SMSystemExclusiveMessage *)message;
{
    return message;
}

//
// Actions
//

- (IBAction)save:(id)sender;
{
    [[NSSavePanel savePanel] beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

@end


@implementation SMMSysExWindowController (NotificationsDelegatesDataSources)

- (void)windowWillClose:(NSNotification *)notification;
{
    [[self retain] autorelease];
    [controllers removeObjectIdenticalTo:self];
}

@end


@implementation SMMSysExWindowController (Private)

- (void)displayPreferencesDidChange:(NSNotification *)notification;
{
    [self synchronizeDescriptionFields];
}

- (void)synchronizeDescriptionFields;
{    
    [timeField setStringValue:[message timeStampForDisplay]];
    [manufacturerNameField setStringValue:[message manufacturerName]];
    [sizeField setStringValue:[message sizeForDisplay]];
}

- (NSString *)formatSysExData:(NSData *)data;
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

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:nil];

    if (returnCode == NSOKButton) {
        NSData *dataToWrite;
        
        if ([[OFPreference preferenceForKey:SMMSaveSysExWithEOXAlwaysPreferenceKey] boolValue])
            dataToWrite = [message fullMessageData];
        else
            dataToWrite = [message receivedDataWithStartByte];

        if (![dataToWrite writeToFile:[sheet filename] atomically:YES]) {
            NSString *title, *text;

            title = NSLocalizedStringFromTableInBundle(@"Error", @"MIDIMonitor", [self bundle], "title of error alert sheet");
            text = NSLocalizedStringFromTableInBundle(@"The file could not be saved.", @"MIDIMonitor", [self bundle], "message when writing sysex data to a file fails");

            NSBeginAlertSheet(title, nil, nil, nil, [self window], nil, NULL, NULL, NULL, text);
        }
    }
}

@end
