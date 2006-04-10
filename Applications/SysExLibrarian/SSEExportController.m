#import "SSEExportController.h"
#import "SSEMainWindowController.h"
#import <SnoizeMIDI/SnoizeMIDI.h>


@interface SSEExportController (Private)

- (void)saveSheetDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation SSEExportController

- (id)initWithWindowController:(SSEMainWindowController *)mainWindowController;
{
    if (!(self = [super init]))
        return nil;

    nonretainedMainWindowController = mainWindowController;

    return self;
}

- (void)exportMessages:(NSArray *)messages;
{
    NSSavePanel *savePanel;
    NSString *defaultFileName;
    
    // Pick a file name to export to.
    [messages retain];

    savePanel = [NSSavePanel savePanel];
    [savePanel setRequiredFileType:@"mid"];    

    defaultFileName = NSLocalizedStringFromTableInBundle(@"SysEx", @"SysExLibrarian", SMBundleForObject(self), "default file name for exported standard MIDI file (w/o extension)");
    defaultFileName = [defaultFileName stringByAppendingPathExtension:@"mid"];
    
    [savePanel beginSheetForDirectory:nil file:defaultFileName modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(saveSheetDidEnd:returnCode:contextInfo:) contextInfo:messages];
}

@end


@implementation SSEExportController (Private)

- (void)saveSheetDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSArray *messages = (NSArray *)contextInfo;

    if (returnCode == NSOKButton) {
        NSString *path;
        BOOL success;

        path = [sheet filename];
        success = [SMSystemExclusiveMessage writeSystemExclusiveMessages:messages toStandardMIDIFile:path];

        if (!success) {
            NSString *title, *message;

            title = NSLocalizedStringFromTableInBundle(@"Error", @"SysExLibrarian", SMBundleForObject(self), "title of error alert");
            message = NSLocalizedStringFromTableInBundle(@"The file could not be saved.",  @"SysExLibrarian", SMBundleForObject(self), "message if sysex can't be exported");
            
            NSRunAlertPanel(title, @"%@", nil, nil, nil, message);
        }
    }

    [messages release];
}

@end
