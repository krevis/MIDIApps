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

    // Transient data
    NSArray *missingSourceNames;
    unsigned int sysExBytesRead;
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

@end

// Preference keys
extern NSString *SMMAutoSelectOrdinarySourcesInNewDocumentPreferenceKey;
extern NSString *SMMAutoSelectVirtualDestinationInNewDocumentPreferenceKey;
extern NSString *SMMAutoSelectSpyingDestinationsInNewDocumentPreferenceKey;
