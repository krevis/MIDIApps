//
// Copyright 2001-2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@interface SMClient : OFObject
{
    MIDIClientRef midiClient;
    NSString *name;
    BOOL postsExternalSetupChangeNotification;
    BOOL isHandlingSetupChange;
    CFBundleRef coreMIDIFrameworkBundle;
    NSMutableDictionary *coreMIDIPropertyNameDictionary;
}

+ (SMClient *)sharedClient;

- (MIDIClientRef)midiClient;
- (NSString *)name;

- (BOOL)postsExternalSetupChangeNotification;
- (void)setPostsExternalSetupChangeNotification:(BOOL)value;

- (BOOL)isHandlingSetupChange;

- (CFStringRef)coreMIDIPropertyNameConstantNamed:(NSString *)name;

@end

// Notifications

extern NSString *SMClientCreatedInternalNotification;
extern NSString *SMClientSetupChangedInternalNotification;
extern NSString *SMClientSetupChangedNotification;
    // No userInfo

extern NSString *SMClientMIDINotification;
    // userInfo contains these keys and values:
    //	SMClientMIDINotificationID		NSNumber	(an int)
    //	SMClientMIDINotificationData	NSData		(optional)
extern NSString *SMClientMIDINotificationID;
extern NSString *SMClientMIDINotificationData;
