//
// Copyright 2004 Kurt Revis. All rights reserved.
//

#import "NSDictionary-SMMExtensions.h"


@implementation NSDictionary (SMMExtensions)

- (NSData *)SMM_xmlPropertyListData
{
	return [(NSData *)CFPropertyListCreateXMLData(NULL, (CFPropertyListRef)self) autorelease];
}

@end
