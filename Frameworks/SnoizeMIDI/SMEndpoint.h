#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMEndpoint : OFObject
{
    MIDIEndpointRef endpointRef;
    SInt32 uniqueID;
    MIDIDeviceRef deviceRef;
    struct {
        unsigned int hasLookedForDevice:1;
    } flags;
}

+ (SInt32)generateNewUniqueID;

- (id)initWithEndpointRef:(MIDIEndpointRef)anEndpointRef;

- (MIDIEndpointRef)endpointRef;

- (BOOL)isVirtual;
- (BOOL)isOwnedByThisProcess;
- (void)setIsOwnedByThisProcess;

- (SInt32)uniqueID;
- (void)setUniqueID:(SInt32)value;

- (NSString *)name;
- (void)setName:(NSString *)value;
    // Endpoint name, as returned by CoreMIDI (kMIDIPropertyName)
    
- (NSString *)manufacturerName;
- (void)setManufacturerName:(NSString *)value;

- (NSString *)modelName;
- (void)setModelName:(NSString *)value;

- (NSString *)shortName;
    // If all endpoints of the same kind (source or destination) have unique names,
    // returns -name. Otherwise, returns -longName.

- (NSString *)longName;
    // Returns "<device name> <endpoint name>". If there is no device for this endpoint
    // (that is, if it's virtual) return "<model name> <endpoint name>".

- (SInt32)advanceScheduleTime;
- (void)setAdvanceScheduleTime:(SInt32)newValue;
    // Value is in milliseconds

@end


@interface SMSourceEndpoint : SMEndpoint
{
}

+ (NSArray *)sourceEndpoints;
+ (SMSourceEndpoint *)sourceEndpointWithUniqueID:(SInt32)uniqueID;
+ (SMSourceEndpoint *)sourceEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;

@end


@interface SMDestinationEndpoint : SMEndpoint
{
}

+ (NSArray *)destinationEndpoints;
+ (SMDestinationEndpoint *)destinationEndpointWithUniqueID:(SInt32)uniqueID;
+ (SMDestinationEndpoint *)destinationEndpointWithEndpointRef:(MIDIEndpointRef)anEndpointRef;

@end


// Notifications

extern NSString *SMEndpointAppearedNotification;
extern NSString *SMEndpointDisappearedNotification;
extern NSString *SMEndpointWasReplacedNotification;
    // userInfo contains new endpoint under key SMEndpointReplacement
extern NSString *SMEndpointReplacement;

// MIDI property keys

extern NSString *SMEndpointPropertyOwnerPID;
    // We set this on the virtual endpoints that we create, so we can query them to see if they're ours.
