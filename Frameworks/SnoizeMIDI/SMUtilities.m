//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMUtilities.h"
#import <AvailabilityMacros.h>
#import <objc/objc-class.h>


void SMRequestConcreteImplementation(id self, SEL _cmd)
{
    NSString *message = [NSString stringWithFormat:@"Object %@ of class %@ has no concrete implementation of selector %s", self, NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    NSAssert(NO, message);
}

void SMRejectUnusedImplementation(id self, SEL _cmd)
{
    NSString *message = [NSString stringWithFormat:@"Object %@ of class %@ was sent selector %s which should be not be used", self, NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    NSAssert(NO, message);
}

BOOL SMClassIsSubclassOfClass(Class class, Class potentialSuperclass)
{
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_2
    return [class isSubclassOfClass:potentialSuperclass];
#else
    while (class) {
        if (class == potentialSuperclass)
            return YES;
        class = class->super_class;
    }
    
    return NO;
#endif
}

#if DEBUG

extern void SMAssertionFailed(const char *expression, const char *file, unsigned int line)
{
    NSLog(@"SnoizeMIDI: Assertion failed: condition %s, file %s, line %u", expression, file, line);
}

#endif
