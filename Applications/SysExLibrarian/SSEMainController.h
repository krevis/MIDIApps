#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SnoizeMIDI.h>

@class SSEMainWindowController;


@interface SSEMainController : NSObject <SMMessageDestination>
{
    IBOutlet SSEMainWindowController *windowController;

    // MIDI processing
    SMPortOrVirtualInputStream *inputStream;
    SMPortOrVirtualOutputStream *outputStream;
    
    // Transient data
    BOOL listenToMIDISetupChanges;
    unsigned int sysExBytesRead;    
}

- (NSArray *)sourceDescriptions;
- (NSDictionary *)sourceDescription;
- (void)setSourceDescription:(NSDictionary *)sourceDescription;

- (NSArray *)destinationDescriptions;
- (NSDictionary *)destinationDescription;
- (void)setDestinationDescription:(NSDictionary *)destinationDescription;

@end
