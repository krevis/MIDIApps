//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "SMWorkaroundSysExSendRequest.h"

#import "SMEndpoint.h"
#import "SMSystemExclusiveMessage.h"


@interface SMWorkaroundSysExSendRequest (Private)

static void workaroundCompletionProc(MIDISysexSendRequest *request);
- (void)workaroundCompletionProc;

@end


@implementation SMWorkaroundSysExSendRequest

- (id)initWithMessage:(SMSystemExclusiveMessage *)aMessage endpoint:(SMDestinationEndpoint *)endpoint;
{
    if (![super initWithMessage:aMessage endpoint:endpoint])
        return nil;

    realBytesToSend = request.bytesToSend;
    // We can't send fewer than 3 bytes of data
    if (realBytesToSend < 3) {
        [self release];
        return nil;
    } else {
        request.bytesToSend = 3;
        bytesInLastPacket = 3;
    }
    
    realCompletionProc = request.completionProc;
    request.completionProc = workaroundCompletionProc;

    reallyComplete = NO;
    
    return self;
}

- (BOOL)cancel;
{
    if (reallyComplete)
        return NO;

    reallyComplete = YES;
    return YES;    
}

- (unsigned int)bytesRemaining;
{
    return realBytesToSend;
}

@end


@implementation SMWorkaroundSysExSendRequest (Private)

static void workaroundCompletionProc(MIDISysexSendRequest *request)
{
// NOTE There is no need for an autorelease pool here, so let's not make one and slow things down.
//    NSAutoreleasePool *pool;
//    pool = [[NSAutoreleasePool alloc] init];

    [(SMWorkaroundSysExSendRequest *)(request->completionRefCon) workaroundCompletionProc];

//    [pool release];
}

- (void)workaroundCompletionProc;
{
    realBytesToSend -= (bytesInLastPacket - request.bytesToSend);
    if (realBytesToSend == 0)
        reallyComplete = YES;

    if (!reallyComplete) {
        OSStatus status;

        request.data += bytesInLastPacket;
        request.bytesToSend = MIN(3, realBytesToSend);
        bytesInLastPacket = request.bytesToSend;
        request.complete = FALSE;

        status = MIDISendSysex(&request);
        if (status)
            reallyComplete = YES;	// Error, so act like the request got cancelled
    }

    if (reallyComplete) {
        request.bytesToSend = realBytesToSend;
        request.complete = TRUE;
        realCompletionProc(&request);
    }
}

@end
