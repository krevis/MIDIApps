#import "SSEDetailsWindowController.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

#import "SSELibrary.h"
#import "SSELibraryEntry.h"
#import "SSEPreferencesWindowController.h"


@interface SSEDetailsWindowController (Private)

- (void)_synchronizeMessageDataDisplay;
- (void)_synchronizeTitle;

- (void)_displayPreferencesDidChange:(NSNotification *)notification;
- (void)_entryWillBeRemoved:(NSNotification *)notification;
- (void)_entryNameDidChange:(NSNotification *)notification;

- (NSString *)_formatSysExData:(NSData *)data;

@end


@implementation SSEDetailsWindowController

static NSMutableArray *controllers = nil;

+ (SSEDetailsWindowController *)detailsWindowControllerWithEntry:(SSELibraryEntry *)inEntry;
{
    unsigned int controllerIndex;
    SSEDetailsWindowController *controller;

    if (!controllers) {
        controllers = [[NSMutableArray alloc] init];
    }

    controllerIndex = [controllers count];
    while (controllerIndex--) {
        controller = [controllers objectAtIndex:controllerIndex];
        if ([controller entry] == inEntry)
            return controller;
    }

    controller = [[SSEDetailsWindowController alloc] initWithEntry:inEntry];
    [controllers addObject:controller];
    [controller release];

    return controller;
}

- (id)initWithEntry:(SSELibraryEntry *)inEntry;
{
    if (!(self = [super initWithWindowNibName:@"Details"]))
        return nil;

    [self setShouldCascadeWindows:YES];

    entry = [inEntry retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_entryWillBeRemoved:) name:SSELibraryEntryWillBeRemovedNotification object:entry];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_entryNameDidChange:) name:SSELibraryEntryNameDidChangeNotification object:entry];
    
    cachedMessages = [[NSArray alloc] initWithArray:[entry messages]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_displayPreferencesDidChange:) name:SSEDisplayPreferenceChangedNotification object:nil];

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [entry release];
    entry = nil;
    [cachedMessages release];
    cachedMessages = nil;
        
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    [[self window] setExcludedFromWindowsMenu:NO];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self _synchronizeTitle];
    
    [messagesTableView reloadData];
    if ([cachedMessages count] > 0)
        [messagesTableView selectRow:0 byExtendingSelection:NO];

    [self _synchronizeMessageDataDisplay];
}

- (SSELibraryEntry *)entry;
{
    return entry;
}

@end


@implementation SSEDetailsWindowController (NotificationsDelegatesDataSources)

//
// NSWindow delegate
//

- (void)windowWillClose:(NSNotification *)notification;
{
    [[self retain] autorelease];
    [controllers removeObjectIdenticalTo:self];
}

//
// NSTableView data source
//

- (int)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [cachedMessages count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    NSString *identifier;
    SMSystemExclusiveMessage *message;

    identifier = [tableColumn identifier];
    message = [cachedMessages objectAtIndex:row];

    if ([identifier isEqualToString:@"index"]) {
        return [NSNumber numberWithInt:row + 1];
    } else if ([identifier isEqualToString:@"manufacturer"]) {
        return [message manufacturerName];
    } else if ([identifier isEqualToString:@"size"]) {
        return [message sizeForDisplay];
        // TODO need to expose preference for this?
        // TODO have separate columns for size in hex and decimal (and abbreviated)?
    } else {
        return nil;
    }
}

//
// NSTableView delegate
//

- (void)tableViewSelectionDidChange:(NSNotification *)notification;
{
    [self _synchronizeMessageDataDisplay];
}

@end


@implementation SSEDetailsWindowController (Private)

- (void)_synchronizeMessageDataDisplay;
{
    int selectedRow;
    NSString *formattedData;

    selectedRow = [messagesTableView selectedRow];
    if (selectedRow >= 0) {
        formattedData = [self _formatSysExData:[[cachedMessages objectAtIndex:selectedRow] receivedDataWithStartByte]];
    } else {
        formattedData = @"";
    }

    [textView setString:formattedData];
}

- (void)_synchronizeTitle;
{
    [[self window] setTitle:[entry name]];
    [[self window] setRepresentedFilename:[entry path]];
}

- (void)_displayPreferencesDidChange:(NSNotification *)notification;
{
    // TODO
}

- (void)_entryWillBeRemoved:(NSNotification *)notification;
{
    [self close];
}

- (void)_entryNameDidChange:(NSNotification *)notification;
{
    [self _synchronizeTitle];
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
