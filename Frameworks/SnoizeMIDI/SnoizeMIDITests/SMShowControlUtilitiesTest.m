//
//  SMShowControlUtilitiesTest.m
//  SnoizeMIDITests
//
//  Created by Hugo Trippaers on 22/12/2018.
//

#import <XCTest/XCTest.h>

#import <SnoizeMIDI/SMShowControlUtilities.h>

@interface SMShowControlUtilitiesTest : XCTestCase

@end

@implementation SMShowControlUtilitiesTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testParseTimecodeWithFractionalFrames {
    Byte bytes[] = { 0x61, 0x02, 0x03, 0x04, 0x05 };
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMTimecode timecode = parseTimecodeData(testData);
    
    XCTAssertEqual(timecode.hours, 1);
    XCTAssertEqual(timecode.timecodeType, 3);
    XCTAssertEqual(timecode.minutes, 2);
    XCTAssertEqual(timecode.seconds, 3);
    XCTAssertEqual(timecode.frames, 4);
    XCTAssertEqual(timecode.subframes, 5);
    XCTAssertEqual(timecode.colorFrameBit, 0);
    XCTAssertEqual(timecode.form, 0);
    XCTAssertEqual(timecode.sign, 0);
}

- (void)testParseTimecodeWithStatus {
    Byte bytes[] = { 0x61, 0x02, 0x03, 0x24, 0x50 };
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMTimecode timecode = parseTimecodeData(testData);
    
    XCTAssertEqual(timecode.hours, 1);
    XCTAssertEqual(timecode.timecodeType, 3);
    XCTAssertEqual(timecode.minutes, 2);
    XCTAssertEqual(timecode.seconds, 3);
    XCTAssertEqual(timecode.frames, 4);
    XCTAssertEqual(timecode.subframes, 0);
    XCTAssertEqual(timecode.colorFrameBit, 0);
    XCTAssertEqual(timecode.form, 1);
    XCTAssertEqual(timecode.sign, 0);
    XCTAssertEqual(timecode.statusVideoFieldIndentification, 1);
    XCTAssertEqual(timecode.statusInvalidCode, 0);
    XCTAssertEqual(timecode.statusEstimatedCodeFlag, 1);
}

- (void)testParseCueListWithSingleCue {
    Byte bytes[] = { 0x31, 0x31 };
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    NSArray *cues = parseCueItemsData(testData);
    
    XCTAssertEqual([cues count], 1);
    XCTAssertEqualObjects([cues objectAtIndex:0], @"11");
}

- (void)testParseCueListWithFullPath {
    Byte bytes[] = { 0x31, 0x31, 0x00, 0x32, 0x32, 0x00, 0x33, 0x33 };
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    NSArray *cues = parseCueItemsData(testData);
    
    XCTAssertEqual([cues count], 3);
    XCTAssertEqualObjects([cues objectAtIndex:0], @"11");
    XCTAssertEqualObjects([cues objectAtIndex:1], @"22");
    XCTAssertEqualObjects([cues objectAtIndex:2], @"33");
}

- (void)testParseCueListWithFullPathOfOneNumberCues {
    Byte bytes[] = { 0x31, 0x00, 0x32, 0x00, 0x33 };
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    NSArray *cues = parseCueItemsData(testData);
    
    XCTAssertEqual([cues count], 3);
    XCTAssertEqualObjects([cues objectAtIndex:0], @"1");
    XCTAssertEqualObjects([cues objectAtIndex:1], @"2");
    XCTAssertEqualObjects([cues objectAtIndex:2], @"3");
}

- (void)testParseCueListWithoutEntries {
    Byte bytes[] = { 0xF7 };
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    NSArray *cues = parseCueItemsData(testData);

    // TODO This is failing, returning 1 not 0
    XCTAssertEqual([cues count], 0);
}

@end
