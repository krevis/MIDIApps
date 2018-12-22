//
//  SMShowControlMessageTest.m
//  SnoizeMIDI
//
//  Created by Hugo Trippaers on 13/12/2018.
//

#import <XCTest/XCTest.h>

#import "SMShowControlMessage.h"

@interface SMShowControlMessageTest : XCTestCase

@end

@implementation SMShowControlMessageTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testConstructor {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x01 };
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:5];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    [message setWasReceivedWithEOX:TRUE];
    
    XCTAssertNotNil(message);
    XCTAssert([message wasReceivedWithEOX] == TRUE);
}

- (void)testDataForDisplay {
    // MSC GO, no cue params
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x01 };
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:5];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"GO", [message dataForDisplay]);
}

- (void)testDataForDisplayWithCueData {
    // MSC GO, all cue params
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x01, 0x31, 0x32, 0x33, 0x00, 0x34, 0x35, 0x36, 0x00, 0x32, 0x33, 0x2E, 0x32 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:17];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"GO Cue 123, List 456, Path 23.2", [message dataForDisplay]);
}

- (void)testDataForDisplayWithPartialCueData {
    // MSC GO/JAMCLOCK, some cue params
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x10, 0x31, 0x32, 0x33, 0x00, 0x32, 0x33, 0x2E, 0x32 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"GO/JAM_CLOCK Cue 123, List 23.2", [message dataForDisplay]);
}

- (void)testDataForDisplayWithTimedGo {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x04, 0x61, 0x02, 0x03, 0x04, 0x05,
        0x31, 0x00, 0x32 };

    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"TIMED_GO Cue 1, List 2 @ 1:02:03:04/05 (30 fps/non-drop)", [message dataForDisplay]);
}

- (void)testDataForDisplayWithTimedGoWithoutCueList {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x04, 0x61, 0x02, 0x03, 0x04, 0x05 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"TIMED_GO @ 1:02:03:04/05 (30 fps/non-drop)", [message dataForDisplay]);
}

- (void)testDataForSet {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x06, 0x0C, 0x04, 0x29, 0x03 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"SET Control 524 to value 425", [message dataForDisplay]);
}

- (void)testDataForSetWithTimecode {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x06, 0x0C, 0x04, 0x29, 0x03, 0x61, 0x02, 0x03, 0x04, 0x05 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"SET Control 524 to value 425 @ 1:02:03:04/05 (30 fps/non-drop)", [message dataForDisplay]);
}

- (void)testDataForFire {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x07, 0x65 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"FIRE Macro 101", [message dataForDisplay]);
}

- (void)testDataForZeroClock {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x17, 0x32, 0x31 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"ZERO_CLOCK Cue List 21", [message dataForDisplay]);
}

- (void)testDataForOpenCuePath {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x1D, 0x32, 0x31 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"OPEN_CUE_PATH Cue Path 21", [message dataForDisplay]);
}

- (void)testDataForSetClockWithCue {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x18, 0x61, 0x02, 0x03, 0x04, 0x05, 0x32, 0x31 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"SET_CLOCK 1:02:03:04/05 (30 fps/non-drop) for Cue List 21", [message dataForDisplay]);
}

- (void)testDataForSetClockWithoutCue {
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x18, 0x61, 0x02, 0x03, 0x04, 0x05 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"SET_CLOCK 1:02:03:04/05 (30 fps/non-drop)", [message dataForDisplay]);
}

@end
