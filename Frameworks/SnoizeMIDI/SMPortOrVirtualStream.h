#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>

@class SMEndpoint;


@interface SMPortOrVirtualStream : OFObject
{
    id virtualStream;
    id portStream;
    SInt32 virtualEndpointUniqueID;
    NSString *virtualEndpointName;
    NSString *virtualDisplayName;
}

- (NSArray *)endpointDescriptions;
- (NSDictionary *)endpointDescription;
- (void)setEndpointDescription:(NSDictionary *)endpointDescription;

- (NSString *)virtualEndpointName;
- (void)setVirtualEndpointName:(NSString *)newName;

- (NSString *)virtualDisplayName;
- (void)setVirtualDisplayName:(NSString *)newName;

- (NSDictionary *)persistentSettings;
- (NSString *)takePersistentSettings:(NSDictionary *)settings;
    // If the endpoint couldn't be found, its name is returned

- (id)stream;
    // Returns the actual stream in use (either virtualStream or portStream)

// To be implemented by subclasses
- (NSArray *)allEndpoints;
- (SMEndpoint *)endpointWithUniqueID:(int)uniqueID;
- (id)newPortStream;
- (void)willRemovePortStream;
- (id)newVirtualStream;
- (void)willRemoveVirtualStream;

// To be used only by subclasses (TODO move to a private header or something)
- (void)portStreamEndpointWasRemoved:(NSNotification *)notification;

@end

// Notifications
extern NSString *SMPortOrVirtualStreamEndpointWasRemoved;
