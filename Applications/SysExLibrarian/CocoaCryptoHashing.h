/*
 * CocoaCryptoHashing.h
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

#import <openssl/md5.h>
#import <openssl/sha.h>

#import <Foundation/Foundation.h>

@interface NSString (CocoaCryptoHashing)

/*!
 * @method md5Hash
 * @abstract Calculates the MD5 hash from the UTF-8 representation of the specified string  and returns the binary representation
 * @result A NSData object containing the binary representation of the MD5 hash
 */
- (NSData *)md5Hash;

/*!
 * @method md5HexHash
 * @abstract Calculates the MD5 hash from the UTF-8 representation of the specified string and returns the hexadecimal representation
 * @result A NSString object containing the hexadecimal representation of the MD5 hash
 */
- (NSString *)md5HexHash;

/*!
 * @method sha1Hash
 * @abstract Calculates the SHA-1 hash from the UTF-8 representation of the specified string  and returns the binary representation
 * @result A NSData object containing the binary representation of the SHA-1 hash
 */
- (NSData *)sha1Hash;

/*!
 * @method sha1HexHash
 * @abstract Calculates the SHA-1 hash from the UTF-8 representation of the specified string and returns the hexadecimal representation
 * @result A NSString object containing the hexadecimal representation of the SHA-1 hash
 */
- (NSString *)sha1HexHash;

@end

@interface NSData (CocoaCryptoHashing)

/*!
 * @method md5Hash
 * @abstract Calculates the MD5 hash from the data in the specified NSData object  and returns the binary representation
 * @result A NSData object containing the binary representation of the MD5 hash
 */
- (NSData *)md5Hash;

/*!
 * @method md5HexHash
 * @abstract Calculates the MD5 hash from the data in the specified NSData object and returns the hexadecimal representation
 * @result A NSString object containing the hexadecimal representation of the MD5 hash
 */
- (NSString *)md5HexHash;

/*!
 * @method sha1Hash
 * @abstract Calculates the SHA-1 hash from the data in the specified NSData object  and returns the binary representation
 * @result A NSData object containing the binary representation of the SHA-1 hash
 */
- (NSData *)sha1Hash;

/*!
 * @method sha1HexHash
 * @abstract Calculates the SHA-1 hash from the data in the specified NSData object and returns the hexadecimal representation
 * @result A NSString object containing the hexadecimal representation of the SHA-1 hash
 */
- (NSString *)sha1HexHash;

@end
