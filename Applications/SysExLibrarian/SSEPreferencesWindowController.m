#import "SSEPreferencesWindowController.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>


@interface  SSEPreferencesWindowController (Private)

- (void)_synchronizeDefaults;

@end


@implementation SSEPreferencesWindowController

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

//    timeFormatPreference = [[OFPreference preferenceForKey:SMTimeFormatPreferenceKey] retain];

    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
//    [timeFormatPreference release];
    
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
}

- (void)windowDidLoad
{
    [super windowDidLoad];

//    [timeFormatMatrix selectCellWithTag:[timeFormatPreference integerValue]];
}


//
// Actions
//

/* TODO For example:
- (IBAction)changeTimeFormat:(id)sender;
{
    [timeFormatPreference setIntegerValue:[[sender selectedCell] tag]];
    [self _synchronizeDefaults];
}
*/

@end


@implementation SSEPreferencesWindowController (Private)

- (void)_synchronizeDefaults;
{
    [[NSUserDefaults standardUserDefaults] autoSynchronize];
}

@end
