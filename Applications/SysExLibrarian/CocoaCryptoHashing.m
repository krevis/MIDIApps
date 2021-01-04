/*
 * CocoaCryptoHashing.m
 * CocoaCryptoHashing
 * 
 * Copyright (c) 2004-2005 Denis Defreyne
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * 
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * 
 * - The names of its contributors may not be used to endorse or promote
 *   products derived from this software without specific prior written
 *   permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "CocoaCryptoHashing.h"

#import <CommonCrypto/CommonDigest.h>


@implementation NSString (CocoaCryptoHashing)

- (NSData *)md5Hash
{
	return [[self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO] md5Hash];
}

- (NSString *)md5HexHash
{
	return [[self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO] md5HexHash];
}

- (NSData *)sha1Hash
{
	return [[self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO] sha1Hash];
}

- (NSString *)sha1HexHash
{
	return [[self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO] sha1HexHash];
}

@end

@implementation NSData (CocoaCryptoHashing)

- (NSString *)md5HexHash
{
	unsigned char digest[16];
    NSMutableString *result = [NSMutableString stringWithCapacity:16 * 2];

	CC_MD5([self bytes], (CC_LONG)[self length], digest);
    for (int i=0; i < 16; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }

    return result;
}

- (NSData *)md5Hash
{
	unsigned char digest[16];
	
	CC_MD5([self bytes], (CC_LONG)[self length], digest);
	
	return [NSData dataWithBytes:&digest length:16];
}

- (NSString *)sha1HexHash
{
	unsigned char digest[20];
    NSMutableString *result = [NSMutableString stringWithCapacity:20 * 2];

	CC_SHA1([self bytes], (CC_LONG)[self length], digest);
    for (int i=0; i < 20; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }

    return result;
}

- (NSData *)sha1Hash
{
	unsigned char digest[20];
	
	CC_SHA1([self bytes], (CC_LONG)[self length], digest);
	
	return [NSData dataWithBytes:&digest length:20];
}

@end
