/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <SnoizeMIDI/SnoizeMIDI.h>

@class SMMCombinationInputStream;
@class SMMDetailsWindowController;
@class SMMMonitorWindowController;


@interface SMMDocument : NSDocument

- (NSArray *)groupedInputSources;
    // Returns an array of dictionaries; each has a string for key @"name" and an array of source descriptions for key @"sources"

@property (nonatomic, retain) NSSet* selectedInputSources;

@property (nonatomic, assign) NSUInteger maxMessageCount;

- (SMMessageType)filterMask;
- (void)changeFilterMask:(SMMessageType)maskToChange turnBitsOn:(BOOL)turnBitsOn;

- (BOOL)isShowingAllChannels;
- (NSUInteger)oneChannelToShow;
- (void)showAllChannels;
- (void)showOnlyOneChannel:(NSUInteger)channel;

@property (nonatomic, readonly, copy) NSDictionary *windowSettings;

- (void)clearSavedMessages;
- (NSArray *)savedMessages;

- (SMMMonitorWindowController *)monitorWindowController;
- (NSArray *)detailsWindowControllers;
- (SMMDetailsWindowController *)detailsWindowControllerForMessage:(SMMessage *)message;
- (void)encodeRestorableState:(NSCoder *)state forDetailsWindowController:(SMMDetailsWindowController *)detailsWC;

@end

// Preference keys
extern NSString* const SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey;
extern NSString* const SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey;
extern NSString* const SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey;
extern NSString* const SMMAskBeforeClosingModifiedWindowPreferenceKey;
