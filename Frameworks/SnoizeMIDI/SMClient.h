#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMClient : OFObject
{
    MIDIClientRef midiClient;
    NSString *name;
    BOOL postsExternalSetupChangeNotification;
}

+ (SMClient *)sharedClient;

- (MIDIClientRef)midiClient;
- (NSString *)name;

- (BOOL)postsExternalSetupChangeNotification;
- (void)setPostsExternalSetupChangeNotification:(BOOL)value;

@end

// Notifications

extern NSString *SMClientSetupChangedInternalNotification;
extern NSString *SMClientSetupChangedNotification;
    // No userInfo

extern NSString *SMClientMIDINotification;
    // userInfo contains these keys and values:
    //	SMClientMIDINotificationID		NSNumber	(an int)
    //	SMClientMIDINotificationData	NSData		(optional)
extern NSString *SMClientMIDINotificationID;
extern NSString *SMClientMIDINotificationData;
