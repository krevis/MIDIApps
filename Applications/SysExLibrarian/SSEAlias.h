//
//  SSEAlias.h
//  SysExLibrarian
//
//  Created by Kurt Revis on 9/3/18.
//

#import <Foundation/Foundation.h>

@interface SSEAlias : NSObject

+ (SSEAlias *)aliasWithData:(NSData *)data;
+ (SSEAlias *)aliasWithPath:(NSString *)path;
+ (SSEAlias *)aliasWithAliasRecordData:(NSData *)data;

- (id)initWithData:(NSData *)data;
- (id)initWithPath:(NSString *)fullPath;
- (id)initWithAliasRecordData:(NSData *)aliasRecordData;

- (NSData *)data;

- (NSString *)path;
- (NSString *)pathAllowingUI:(BOOL)allowUI;

@end
