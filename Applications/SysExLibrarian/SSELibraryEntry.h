#import <OmniFoundation/OFObject.h>
#import <Cocoa/Cocoa.h>


@interface SSELibraryEntry : OFObject
{
    NSString *path;
}

+ (SSELibraryEntry *)libraryEntryFromDictionary:(NSDictionary *)dict;

- (NSDictionary *)dictionaryValues;
- (void)takeValuesFromDictionary:(NSDictionary *)dict;

- (NSString *)path;
- (void)setPath:(NSString *)value;

- (NSString *)name;

- (NSArray *)messages;

@end
