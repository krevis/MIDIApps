/*
 Copyright (c) 2001-2018, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SMMWindowController.h"


@interface SMMPreferencesWindowController : SMMWindowController

+ (SMMPreferencesWindowController *)preferencesWindowController;

- (IBAction)changeTimeFormat:(id)sender;
- (IBAction)changeNoteFormat:(id)sender;
- (IBAction)changeControllerFormat:(id)sender;
- (IBAction)changeDataFormat:(id)sender;
- (IBAction)changeProgramChangeBaseIndex:(id)sender;
- (IBAction)changeAutoSelectOrdinarySources:(id)sender;
- (IBAction)changeAutoSelectVirtualDestination:(id)sender;
- (IBAction)changeAutoSelectSpyingDestinations:(id)sender;
- (IBAction)changeAskBeforeClosingModifiedWindow:(id)sender;
- (IBAction)changeAlwaysSaveSysExWithEOX:(id)sender;
- (IBAction)changeExpertMode:(id)sender;
- (IBAction)changeNewSourcesRadio:(id)sender;


@end

// Notifications
extern NSString* const SMMDisplayPreferenceChangedNotification;
