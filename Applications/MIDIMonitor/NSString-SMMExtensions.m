//
// Copyright 2004 Kurt Revis. All rights reserved.
//

#import "NSString-SMMExtensions.h"


@implementation NSString (SMMExtensions)

+ (NSString *)SMM_emdashString;
{
	static NSString* emdashString = nil;
	
	if (!emdashString) {
		unichar emdashChar = 0x2014;
		emdashString = [[NSString alloc] initWithCharacters:&emdashChar length:1];
	}
	
	return emdashString;
}

@end
