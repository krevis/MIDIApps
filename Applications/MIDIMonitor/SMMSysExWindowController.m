#import "SMMSysExWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SMMPreferencesWindowController.h"


@interface SMMSysExWindowController (Private)

- (void)_autosaveWindowFrame;

- (void)_displayPreferencesDidChange:(NSNotification *)notification;

- (void)_synchronizeDescriptionFields;

- (NSString *)_formatSysExData:(NSData *)data;


@end


@implementation SMMSysExWindowController

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

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_displayPreferencesDidChange:) name:SMMDisplayPreferenceChangedNotification object:nil];
    
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

- (void)awakeFromNib
{
    [[self window] setFrameAutosaveName:[self windowNibName]];
    // TODO We are not setting the window frame from this setting, though, it doesn't seem. Probably we should do that.
    // (still need to cascade)
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self _synchronizeDescriptionFields];

    [textView setString:[self _formatSysExData:[message receivedData]]];
}

- (SMSystemExclusiveMessage *)message;
{
    return message;
}

//
// Actions
//


@end


@implementation SMMSysExWindowController (NotificationsDelegatesDataSources)

- (void)windowDidResize:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowDidMove:(NSNotification *)notification;
{
    [self _autosaveWindowFrame];
}

- (void)windowWillClose:(NSNotification *)notification;
{
    [controllers removeObjectIdenticalTo:self];
    // NOTE We've now been released and probably deallocated! Don't do anything else!
}

@end


@implementation SMMSysExWindowController (Private)

- (void)_autosaveWindowFrame;
{
    // Work around an AppKit bug: the frame that gets saved in NSUserDefaults is the window's old position, not the new one.
    // We get notified after the window has been moved/resized and the defaults changed.

    NSWindow *window;
    NSString *autosaveName;
    
    window = [self window];
    // Sometimes we get called before the window's autosave name is set (when the nib is loading), so check that.
    if ((autosaveName = [window frameAutosaveName])) {
        [window saveFrameUsingName:autosaveName];
        [[NSUserDefaults standardUserDefaults] autoSynchronize];
    }
}

- (void)_displayPreferencesDidChange:(NSNotification *)notification;
{
    [self _synchronizeDescriptionFields];
}

- (void)_synchronizeDescriptionFields;
{
    [timeField setStringValue:[message timeStampForDisplay]];
    [manufacturerNameField setStringValue:[message manufacturerName]];
    [sizeField setStringValue:[SMMessage formatLength:[message receivedDataLength]]];
}

- (NSString *)_formatSysExData:(NSData *)data;
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
        char lineBuffer[64];
        char *p;
        unsigned int index;
        NSString *lineString;

        // This C stuff may be a little ugly but it is a hell of a lot faster than doing it with NSStrings...

        p = lineBuffer;
        p += sprintf(p, "%.*X", lengthDigitCount, dataIndex);
        
        for (index = dataIndex; index < dataIndex+16 && index < dataLength; index++) {
            unsigned char byte;

            *p++ = ' ';
            if (index % 8 == 0)
                *p++ = ' ';

            byte = bytes[index];
            *p++ = hexchars[(byte & 0xF0) >> 4];
            *p++ = hexchars[byte & 0x0F];
        }
        *p++ = '\n';
        *p++ = 0;

        lineString = [[NSString alloc] initWithCString:lineBuffer];
        [formattedString appendString:lineString];
        [lineString release];
    }

    return formattedString;
}

@end
