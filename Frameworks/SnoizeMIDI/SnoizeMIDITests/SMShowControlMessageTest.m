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
    // MSC GO, all cue params
    Byte bytes[] = { 0x7F, 0x00, 0x02, 0x7F, 0x01, 0x31, 0x32, 0x33, 0x00, 0x32, 0x33, 0x2E, 0x32 };
    
    NSData *testData = [[NSData alloc] initWithBytes:bytes length:sizeof bytes];
    
    SMShowControlMessage *message = [SMShowControlMessage showControlMessageWithTimeStamp:0 data:testData];
    
    XCTAssertEqualObjects(@"GO Cue 123, List 23.2", [message dataForDisplay]);
}

@end
