//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <OmniFoundation/OFObject.h>
#import <Foundation/Foundation.h>


@protocol SMInputStreamSource <NSObject>

- (NSString *)inputStreamSourceName;
- (NSNumber *)inputStreamSourceUniqueID;

@end


@interface SMSimpleInputStreamSource : OFObject <SMInputStreamSource>
{
    NSString *name;
}

- (id)initWithName:(NSString *)aName;

- (NSString *)inputStreamSourceName;
- (NSNumber *)inputStreamSourceUniqueID;
    // just returns nil

- (void)setName:(NSString *)value;

@end
