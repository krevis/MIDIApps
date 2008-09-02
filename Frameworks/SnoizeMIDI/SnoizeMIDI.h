/*
 Copyright (c) 2001-2008, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <SnoizeMIDI/SMClient.h>
#import <SnoizeMIDI/SMDevice.h>
#import <SnoizeMIDI/SMEndpoint.h>
#import <SnoizeMIDI/SMExternalDevice.h>
#import <SnoizeMIDI/SMHostTime.h>
#import <SnoizeMIDI/SMInputStream.h>
#import <SnoizeMIDI/SMInputStreamSource.h>
#import <SnoizeMIDI/SMInvalidMessage.h>
#import <SnoizeMIDI/SMMessage.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>
#import <SnoizeMIDI/SMMessageFilter.h>
#import <SnoizeMIDI/SMMessageHistory.h>
#import <SnoizeMIDI/SMMessageMult.h>
#import <SnoizeMIDI/SMMessageTimeBase.h>
#import <SnoizeMIDI/SMMIDIObject.h>
#import <SnoizeMIDI/SMOutputStream.h>
#import <SnoizeMIDI/SMMessageParser.h>
#import <SnoizeMIDI/SMPortInputStream.h>
#import <SnoizeMIDI/SMPortOutputStream.h>
#import <SnoizeMIDI/SMSysExSendRequest.h>
#import <SnoizeMIDI/SMSystemCommonMessage.h>
#import <SnoizeMIDI/SMSystemRealTimeMessage.h>
#import <SnoizeMIDI/SMSystemExclusiveMessage.h>
#import <SnoizeMIDI/SMUtilities.h>
#import <SnoizeMIDI/SMVirtualInputStream.h>
#import <SnoizeMIDI/SMVirtualOutputStream.h>
#import <SnoizeMIDI/SMVoiceMessage.h>
#import <SnoizeMIDI/NSArray-SMExtensions.h>
#import <SnoizeMIDI/NSData-SMExtensions.h>
#import <SnoizeMIDI/NSString-SMExtensions.h>
