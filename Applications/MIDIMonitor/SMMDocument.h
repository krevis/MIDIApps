/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

@class SMMCombinationInputStream;


@interface SMMDocument : NSDocument
{
    // MIDI processing
    SMMCombinationInputStream *stream;
    SMMessageFilter *messageFilter;
    SMMessageHistory *history;

    // Other settings
    BOOL areSourcesShown;
    BOOL isFilterShown;
    NSString *windowFrameDescription;
    NSPoint messagesScrollPoint;

    // Transient data
    NSArray *missingSourceNames;
    unsigned int sysExBytesRead;
	BOOL isSysExUpdateQueued;
}

- (NSArray *)groupedInputSources;
    // Returns an array of dictionaries; each has a string for key @"name" and an array of source descriptions for key @"sources"
- (NSSet *)selectedInputSources;
- (void)setSelectedInputSources:(NSSet *)inputSources;
- (void)revealInputSources:(NSSet *)inputSources;

- (unsigned int)maxMessageCount;
- (void)setMaxMessageCount:(unsigned int)newValue;

- (SMMessageType)filterMask;
- (void)changeFilterMask:(SMMessageType)maskToChange turnBitsOn:(BOOL)turnBitsOn;

- (BOOL)isShowingAllChannels;
- (unsigned int)oneChannelToShow;
- (void)showAllChannels;
- (void)showOnlyOneChannel:(unsigned int)channel;

- (BOOL)areSourcesShown;
- (void)setAreSourcesShown:(BOOL)newValue;

- (BOOL)isFilterShown;
- (void)setIsFilterShown:(BOOL)newValue;

- (NSString *)windowFrameDescription;
- (void)setWindowFrameDescription:(NSString *)value;

- (void)clearSavedMessages;
- (NSArray *)savedMessages;

- (NSPoint)messagesScrollPoint;

@end

// Preference keys
extern NSString *SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey;
extern NSString *SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey;
extern NSString *SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey;
extern NSString *SMMAskBeforeClosingModifiedWindowPreferenceKey;
