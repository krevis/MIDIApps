//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol SMInputStreamSource <NSObject>

- (NSString *)inputStreamSourceName;
- (NSNumber *)inputStreamSourceUniqueID;
- (NSArray *)inputStreamSourceExternalDeviceNames;

@end


@interface SMSimpleInputStreamSource : NSObject <SMInputStreamSource>
{
    NSString *name;
}

- (id)initWithName:(NSString *)aName;

- (NSString *)inputStreamSourceName;
- (NSNumber *)inputStreamSourceUniqueID;
    // just returns nil
- (NSArray *)inputStreamSourceExternalDeviceNames;
    // returns an empty array

- (void)setName:(NSString *)value;

@end
