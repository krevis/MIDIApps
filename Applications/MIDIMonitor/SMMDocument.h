#import <AppKit/NSDocument.h>
#import <CoreMIDI/CoreMIDI.h>
#import <SnoizeMIDI/SnoizeMIDI.h>


@interface SMMDocument : NSDocument
{
    // MIDI processing
    SMPortOrVirtualInputStream *stream;
    SMMessageFilter *messageFilter;
    SMMessageHistory *history;

    // Other settings
    BOOL isFilterShown;
    NSString *windowFrameDescription;

    // Transient data
    BOOL listenToMIDISetupChanges;
    NSString *missingSourceName;
    unsigned int sysExBytesRead;
}

- (NSArray *)sourceDescriptions;
- (NSDictionary *)sourceDescription;
- (void)setSourceDescription:(NSDictionary *)sourceDescription;

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
