//
//  SMShowControlUtilities.h
//  SnoizeMIDI
//
//  Created by Hugo Trippaers on 22/12/2018.
//

#ifndef SMShowControlUtilities_h
#define SMShowControlUtilities_h

// Based on the structure described in
// MIDI Show Control 1.1 pg 6
typedef struct {
    int timecodeType;
    int hours;
    int minutes;
    int seconds;
    int frames;
    int subframes;
    int colorFrameBit;
    int form; // 0 = fractional frames, 1 = status
    int sign; // 0 = positive, 1 = negative
    int statusEstimatedCodeFlag;
    int statusInvalidCode;
    int statusVideoFieldIndentification;
} Timecode;

/*
 * Parses the provided bytes into a timecode structure
 * according to the Timecode format in the MIDI Show
 * Control 1.1 specification
 *
 * Parameters
 *   NSData *timecodeBytes, object with 5 bytes of timecode data
 *
 * Returns
 *   Timecode, struct with all components contains in the timecode data
 */
extern Timecode parseTimecodeBytes(NSData *timecodeBytes);

/*
 * Parses the provided bytes into an array with one
 * string per cue item in the list
 *
 * Parameters
 *   NSData *cueItemsBytes, object with a variable number of bytes terminated by 0xF7
 *
 * Returns
 *   NSArray *, array containing an NSString * for every cueitem found in the data
 */
extern NSArray *parseCueItemsBytes(NSData *cueItemsBytes);

#endif /* SMShowControlUtilities_h */
