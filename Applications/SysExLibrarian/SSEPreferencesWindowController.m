#import "SSEPreferencesWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import "SSEMainWindowController.h"


@interface  SSEPreferencesWindowController (Private)

- (void)_synchronizeDefaults;
- (void)_sendDisplayPreferenceChangedNotification;

@end


@implementation SSEPreferencesWindowController

DEFINE_NSSTRING(SSEDisplayPreferenceChangedNotification);


static SSEPreferencesWindowController *controller;

+ (SSEPreferencesWindowController *)preferencesWindowController;
{
    if (!controller)
        controller = [[self alloc] init];
    
    return controller;
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"Preferences"]))
        return nil;

    sizeFormatPreference = [[OFPreference preferenceForKey:SSEAbbreviateFileSizesInLibraryTableView] retain];

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [sizeFormatPreference release];
    
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [sizeFormatMatrix selectCellWithTag:[sizeFormatPreference boolValue]];
}


//
// Actions
//

- (IBAction)changeSizeFormat:(id)sender;
{
    [sizeFormatPreference setBoolValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
    [self _sendDisplayPreferenceChangedNotification];
}

@end


@implementation SSEPreferencesWindowController (Private)

- (void)_synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] autoSynchronize];
}

- (void)_sendDisplayPreferenceChangedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSEDisplayPreferenceChangedNotification object:nil];
}

@end
