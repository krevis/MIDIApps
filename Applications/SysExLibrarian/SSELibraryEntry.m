#import "SSELibraryEntry.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>



@implementation SSELibraryEntry

+ (SSELibraryEntry *)libraryEntryFromDictionary:(NSDictionary *)dict;
{
    SSELibraryEntry *entry;

    entry = [[[self alloc] init] autorelease];
    [entry takeValuesFromDictionary:dict];

    return entry;
}

- (id)init;
{
    if (![super init])
        return nil;

    return self;
}

- (void)dealloc
{
    [path release];
    
    [super dealloc];
}

- (NSDictionary *)dictionaryValues;
{
    if (path)
        return [NSDictionary dictionaryWithObject:path forKey:@"path"];
    else
        return nil;
}

- (void)takeValuesFromDictionary:(NSDictionary *)dict;
{
    NSString *string;

    string = [dict objectForKey:@"path"];
    if (string)
        [self setPath:string];
}

- (NSString *)path;
{
    return path;
}

- (void)setPath:(NSString *)value;
{
    if (value != path && ![path isEqualToString:value]) {
        [path release];
        path = [value retain];
    }
}

- (NSString *)name;
{
    return [path lastPathComponent];
}

@end
