//
//  SMShowControlMessage.h
//  SnoizeMIDI
//
//  Created by Hugo Trippaers on 11/12/2018.
//

#import <SnoizeMIDI/SMSystemExclusiveMessage.h>
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@interface SMShowControlMessage : SMSystemExclusiveMessage
{
    Byte mscCommand;
}

+ (SMShowControlMessage *)showControlMessageWithTimeStamp:(MIDITimeStamp)aTimeStamp data:(NSData *)aData;

@end
