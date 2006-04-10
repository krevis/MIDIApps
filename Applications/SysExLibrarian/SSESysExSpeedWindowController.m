#import "SSESysExSpeedWindowController.h"

#import <SnoizeMIDI/SnoizeMIDI.h>


@interface  SSESysExSpeedWindowController (Private)

- (void)synchronizeControls;

- (void)captureExternalDevices;

- (void)externalDeviceChanged:(NSNotification *)notification;
- (void)externalDeviceListChanged:(NSNotification *)notification;

@end


@implementation SSESysExSpeedWindowController

static SSESysExSpeedWindowController *controller = nil;

+ (SSESysExSpeedWindowController *)sysExSpeedWindowController;
{
    if (!controller)
        controller = [[self alloc] init];
    
    return controller;
}

- (id)init;
{
    if (!(self = [super initWithWindowNibName:@"SysExSpeed"]))
        return nil;

//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalDeviceListChanged:) name:SMMIDIObjectListChangedNotification object:[SMExternalDevice class]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalDeviceListChanged:) name:SMMIDIObjectListChangedNotification object:[SMDestinationEndpoint class]];

    [self captureExternalDevices];
    
    return self;
}

- (id)initWithWindowNibName:(NSString *)windowNibName;
{
    SMRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [externalDevices release];
    
    [super dealloc];
}

- (IBAction)showWindow:(id)sender;
{
    [self window];	// Make sure the window gets loaded the first time
    [self synchronizeControls];
    [super showWindow:sender];
}

//
// Actions
//


@end


@implementation SSESysExSpeedWindowController (DelegatesNotificationsDataSources)

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [externalDevices count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    SMExternalDevice *device = [externalDevices objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];
    id objectValue = nil;

    if ([identifier isEqualToString:@"name"]) {
        objectValue = [device name];
    } else if ([identifier isEqualToString:@"speed"]) {
        objectValue = [NSNumber numberWithInt:[device maxSysExSpeed]];
    }

    return objectValue;    
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    SMExternalDevice *device = [externalDevices objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];

    if ([identifier isEqualToString:@"speed"]) {
        int newValue = [object intValue];
        if (newValue != [device maxSysExSpeed])
            [device setMaxSysExSpeed:newValue];
    }
}

@end


@implementation SSESysExSpeedWindowController (Private)

- (void)synchronizeControls;
{
    [tableView reloadData];
}

- (void)captureExternalDevices;
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSEnumerator *enumerator = [externalDevices objectEnumerator];
    SMExternalDevice *device;

    while ((device = [enumerator nextObject])) {
        [center removeObserver:self name:SMMIDIObjectPropertyChangedNotification object:device];
    }
    
//    externalDevices = [[SMExternalDevice externalDevices] retain];
    externalDevices = [[SMDestinationEndpoint destinationEndpoints] retain];

    enumerator = [externalDevices objectEnumerator];
    while ((device = [enumerator nextObject])) {
        [center addObserver:self selector:@selector(externalDeviceChanged:) name:SMMIDIObjectPropertyChangedNotification object:device];
    }
}

- (void)externalDeviceChanged:(NSNotification *)notification
{
    NSString* propertyName = [[notification userInfo] objectForKey:SMMIDIObjectChangedPropertyName];
    if ([propertyName isEqualToString:(NSString *)kMIDIPropertyName] || [propertyName isEqualToString:(NSString *)kMIDIPropertyMaxSysExSpeed]) {
        [self finishEditingInWindow];
        // TODO want to make sure editing is canceled, not possibly accepted
        [self synchronizeControls];
    }
}

- (void)externalDeviceListChanged:(NSNotification *)notification
{
    [externalDevices release];
//    externalDevices = [[SMExternalDevice externalDevices] retain];
    externalDevices = [[SMDestinationEndpoint destinationEndpoints] retain];

    [self finishEditingInWindow];
    [tableView deselectAll:nil];
    [self synchronizeControls];    
}

@end
