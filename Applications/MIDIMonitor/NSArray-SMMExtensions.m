//
// Copyright 2004 Kurt Revis. All rights reserved.
//

#import "NSArray-SMMExtensions.h"


@implementation NSArray (SMMExtensions)

- (NSString *)SMM_componentsJoinedByCommaAndAnd;
{
	unsigned int count = [self count];
	
	if (count == 0)
		return @"";
	else if (count == 1)		// "a"
		return [self objectAtIndex: 0];
	else if (count == 2)		// "a and b"
		return [self componentsJoinedByString: @" and "];
	else {						// "a, b, and c"
		NSMutableString *result = [NSMutableString string];
		unsigned int index;

		for (index = 0; index < count; index++)
		{
			NSString* obj = [self objectAtIndex:index];
			[result appendString:obj];
			if (index <= count - 2) {
				[result appendString:@", "];
				if (index == count - 2)
					[result appendString:@" and "]; 
			}
		}
		
		return result;
	}
}

@end
