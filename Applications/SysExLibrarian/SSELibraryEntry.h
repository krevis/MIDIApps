#import <OmniFoundation/OFObject.h>
#import <Cocoa/Cocoa.h>

@class BDAlias;
@class SSELibrary;


@interface SSELibraryEntry : OFObject
{
    SSELibrary *nonretainedLibrary;

    NSString *name;
    BDAlias *alias;

    // Caches of file information
    NSArray *messages;
    NSString *manufacturerName;
    NSNumber *sizeNumber;
    NSNumber *messageCountNumber;
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

- (NSString *)manufacturerName;
- (unsigned int)size;
- (unsigned int)messageCount;

@end
