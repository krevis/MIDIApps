#import <OmniFoundation/OFObject.h>
#import <Cocoa/Cocoa.h>

@class BDAlias;
@class SSELibrary;


@interface SSELibraryEntry : OFObject
{
    NSString *name;
    BDAlias *alias;

    SSELibrary *nonretainedLibrary;
}

- (id)initWithLibrary:(SSELibrary *)library;

- (NSDictionary *)dictionaryValues;
- (void)takeValuesFromDictionary:(NSDictionary *)dict;

- (NSString *)path;
- (void)setPath:(NSString *)value;

- (NSString *)name;
- (void)setName:(NSString *)value;
- (void)setNameFromFile;

- (NSArray *)messages;

@end
