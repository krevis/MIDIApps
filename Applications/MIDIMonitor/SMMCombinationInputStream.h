//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

@class SMMSpyingInputStream;


@interface SMMCombinationInputStream : OFObject <SMMessageDestination> {
    id<SMMessageDestination> nonretainedMessageDestination;

    SMPortInputStream *portInputStream;
    SMVirtualInputStream *virtualInputStream;
    SMMSpyingInputStream *spyingInputStream;
}

- (id<SMMessageDestination>)messageDestination;
- (void)setMessageDestination:(id<SMMessageDestination>)messageDestination;

- (NSArray *)groupedInputSources;
    // Returns an array of arrays; each is a list of valid source descriptions for each input stream
- (NSArray *)selectedInputSources;
- (void)setSelectedInputSources:(NSArray *)inputSources;

- (NSDictionary *)persistentSettings;
- (NSArray *)takePersistentSettings:(NSDictionary *)settings;
    // If any endpoints couldn't be found, their names are returned

@end

// Notifications
// This class will repost notifications from its streams, with self as object.
