#import <OmniFoundation/OFObject.h>
#import <Cocoa/Cocoa.h>

@class BDAlias;


@interface SSELibraryEntry : OFObject
{
    BDAlias *alias;
}

+ (SSELibraryEntry *)libraryEntryFromDictionary:(NSDictionary *)dict;

- (NSDictionary *)dictionaryValues;
- (void)takeValuesFromDictionary:(NSDictionary *)dict;

- (NSString *)path;
- (void)setPath:(NSString *)value;

- (NSString *)name;

- (NSArray *)messages;

@end
