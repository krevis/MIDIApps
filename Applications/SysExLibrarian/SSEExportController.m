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
    
    // Pick a file name to export to.
    [messages retain];

    savePanel = [NSSavePanel savePanel];
    [savePanel setRequiredFileType:@"mid"];    
    
    [savePanel beginSheetForDirectory:nil file:@"SysEx.mid" modalForWindow:[nonretainedMainWindowController window] modalDelegate:self didEndSelector:@selector(saveSheetDidEnd:returnCode:contextInfo:) contextInfo:messages];
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

        if (!success)
            NSRunAlertPanel(@"Error", @"The file could not be saved.", nil, nil, nil);
    }

    [messages release];
}

@end
