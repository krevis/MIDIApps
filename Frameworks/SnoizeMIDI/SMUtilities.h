//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import <Foundation/Foundation.h>


static __inline__ NSBundle *SMBundleForObject(id object) {
    return [NSBundle bundleForClass:[object class]];
}

extern void SMRequestConcreteImplementation(id self, SEL _cmd);
extern void SMRejectUnusedImplementation(id self, SEL _cmd);

extern BOOL SMClassIsSubclassOfClass(Class class, Class potentialSuperclass);

#if DEBUG
#define SMAssert(expression)	if (!(expression)) SMAssertionFailed(#expression, __FILE__, __LINE__)
extern void SMAssertionFailed(const char *expression, const char *file, unsigned int line);
#else
#define SMAssert(expression)
#endif

#define SMInitialize \
    {\
        static BOOL initialized = NO; \
        [super initialize]; \
        if (initialized) \
            return; \
        initialized = YES; \
    }

extern UInt32 SMPacketListSize(const MIDIPacketList *packetList);
    // size, in bytes, of the whole packet list

