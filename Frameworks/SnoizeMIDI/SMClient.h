//
//  SMClient.h
//  SnoizeMIDI.framework
//
//  Created by krevis on Sun Sep 16 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <CoreMIDI/MIDIServices.h>


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
