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
    BOOL isFilterShown;
    NSString *windowFrameDescription;

    // Transient data
    BOOL listenToMIDISetupChanges;
    NSArray *missingSourceNames;
    unsigned int sysExBytesRead;
}

- (NSArray *)groupedInputSources;
    // Returns an array of arrays; each is a list of valid source descriptions for each input stream
- (NSArray *)selectedInputSources;
- (void)setSelectedInputSources:(NSArray *)inputSources;

- (unsigned int)maxMessageCount;
- (void)setMaxMessageCount:(unsigned int)newValue;

- (SMMessageType)filterMask;
- (void)changeFilterMask:(SMMessageType)maskToChange turnBitsOn:(BOOL)turnBitsOn;

- (BOOL)isShowingAllChannels;
- (unsigned int)oneChannelToShow;
- (void)showAllChannels;
- (void)showOnlyOneChannel:(unsigned int)channel;

- (BOOL)isFilterShown;
- (void)setIsFilterShown:(BOOL)newValue;

- (NSString *)windowFrameDescription;
- (void)setWindowFrameDescription:(NSString *)value;

- (void)clearSavedMessages;
- (NSArray *)savedMessages;

@end

// Preference keys
extern NSString *SMMAutoSelectFirstSourceInNewDocumentPreferenceKey;
extern NSString *SMMAutoSelectFirstSourceIfSourceDisappearsPreferenceKey;
