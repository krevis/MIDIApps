//
// Copyright 2004 Kurt Revis. All rights reserved.
//

#import "NSArray-SMMExtensions.h"


@implementation NSData (SMMExtensions)

- (id)SMM_propertyList;
{
	return [(id)CFPropertyListCreateFromXMLData(NULL, (CFDataRef)self, kCFPropertyListImmutable, NULL) autorelease];
}

@end
