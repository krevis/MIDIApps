//
// Copyright 2002 Kurt Revis. All rights reserved.
//

#import "NSData-SMExtensions.h"


@implementation NSData (SMExtensions)

- (NSString *)SnoizeMIDI_lowercaseHexString
{
    unsigned int dataLength;
    const unsigned char *p;
    const unsigned char *end;
    char *resultBuffer;
    char *resultChar;
    NSString *resultString;
    static const char hexchars[] = "0123456789abcdef";

    dataLength = [self length];
    if (dataLength == 0)
        return @"";

    p = [self bytes];
    end = p + dataLength;
    resultBuffer = malloc(2 * dataLength + 1);
    resultChar = resultBuffer;

    while (p < end) {
        unsigned char byte = *p++;
        *resultChar++ = hexchars[(byte & 0xF0) >> 4];
        *resultChar++ = hexchars[byte & 0x0F];
    }

    *resultChar++ = '\0';
    resultString = [NSString stringWithUTF8String:resultBuffer];
    free(resultBuffer);
    
    return resultString;
}

@end
