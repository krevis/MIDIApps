/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
