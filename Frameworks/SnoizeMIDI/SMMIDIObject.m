#import "SMMIDIObject.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"


@interface SMMIDIObject (Private)

static int midiObjectOrdinalComparator(id object1, id object2, void *context);

// Methods used by SMMIDIObject itself, not subclasses

+ (void)privateDidLoad;
+ (void)midiClientCreated:(NSNotification *)notification;
+ (NSSet *)leafSubclasses;
+ (Class)subclassForObjectType:(MIDIObjectType)objectType;

+ (void)midiObjectPropertyChanged:(NSNotification *)notification;
+ (void)midiObjectWasAdded:(NSNotification *)notification;
+ (void)midiObjectWasRemoved:(NSNotification *)notification;

// Methods to be used in SMMIDIObject subclasses

+ (NSMapTable *)midiObjectMapTable;

+ (void)initialMIDISetup;

+ (void)addObjectWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(unsigned int)anOrdinal;
+ (void)removeObjectWithObjectRef:(MIDIObjectRef)anObjectRef;

+ (void)refreshObjectOrdinals;

+ (void)midiSetupChanged:(NSNotification *)notification;

@end


@implementation SMMIDIObject

// This really belongs in the Private category, but +didLoad won't get called if it's in a category. Strange but true.
// NOTE That was fixed in OmniBase recently, but the fixed version seems to rely on private API, so I didn't make the change in my copy of OmniBase.
+ (void)didLoad
{
    [self privateDidLoad];
}

//
// Subclasses must implement these methods so all instances of a their kind of MIDIObject can be found
//

+ (MIDIObjectType)midiObjectType;
{
    OBRequestConcreteImplementation(self, _cmd);
    return kMIDIObjectType_Other;
}

+ (ItemCount)midiObjectCount;
{
    OBRequestConcreteImplementation(self, _cmd);
    return 0;
}

+ (MIDIObjectRef)midiObjectAtIndex:(ItemCount)index;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;        
}

//
// For use by subclasses only
//

+ (void)immediatelyAddObjectWithObjectRef:(MIDIObjectRef)anObjectRef;
{
    // Use a default ordinal to start
    [self addObjectWithObjectRef:anObjectRef ordinal:0];

    // Any of the objects' ordinals may have changed, so refresh them
    [self refreshObjectOrdinals];    
}

//
// Accessors for all objects of this type
//

+ (NSArray *)allObjects;
{
    NSMapTable *mapTable;

    mapTable = [self midiObjectMapTable];
    OBASSERT(mapTable);

    if (mapTable)
        return NSAllMapTableValues(mapTable);
    else
        return nil;
}

+ (NSArray *)allObjectsInOrder;
{
    return [[self allObjects] sortedArrayUsingFunction:midiObjectOrdinalComparator context:NULL];
}

+ (SMMIDIObject *)objectWithUniqueID:(MIDIUniqueID)aUniqueID;
{
    // TODO We may want to change this to use MIDIObjectFindByUniqueID() where it is available (10.2 and greater).
    // However, I bet it's cheaper to look at the local list of unique IDs instead of making a roundtrip to the MIDIServer.
    NSArray *allObjects;
    unsigned int index;

    allObjects = [self allObjects];
    index = [allObjects count];
    while (index--) {
        SMMIDIObject *object;

        object = [allObjects objectAtIndex:index];
        if ([object uniqueID] == aUniqueID)
            return object;
    }

    return nil;
}

+ (SMMIDIObject *)objectWithName:(NSString *)aName;
{
    NSArray *allObjects;
    unsigned int index;

    if (!aName)
        return nil;

    allObjects = [self allObjects];
    index = [allObjects count];
    while (index--) {
        SMMIDIObject *object;

        object = [allObjects objectAtIndex:index];
        if ([[object name] isEqualToString:aName])
            return object;
    }

    return nil;
}

+ (SMMIDIObject *)objectWithObjectRef:(MIDIObjectRef)anObjectRef;
{
    NSMapTable *mapTable;

    if (anObjectRef == NULL)
        return nil;
    
    mapTable = [self midiObjectMapTable];
    OBASSERT(mapTable);

    if (mapTable)
        return NSMapGet(mapTable, anObjectRef);
    else
        return nil;
}


//
// Single object creation and accessors
//

- (id)initWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(unsigned int)anOrdinal;
{
    if (!(self = [super init]))
        return nil;

    OBPRECONDITION(anObjectRef != NULL);
    objectRef = anObjectRef;
    ordinal = anOrdinal;

    // Save the object's uniqueID, since it could become inaccessible later (if the object goes away).
    [self updateUniqueID];

    // Nothing has been cached yet
    flags.hasCachedName = NO;
    
    return self;
}

- (MIDIObjectRef)objectRef;
{
    return objectRef;
}

- (unsigned int)ordinal;
{
    return ordinal;
}

- (void)setOrdinal:(unsigned int)value;
{
    ordinal = value;
}

//
// Specific property access
//

- (MIDIUniqueID)uniqueID;
{
    return uniqueID;
}

- (void)setUniqueID:(MIDIUniqueID)value;
{
    OSStatus status;

    if (value == uniqueID)
        return;

    [self checkIfPropertySetIsAllowed];

    status = MIDIObjectSetIntegerProperty(objectRef, kMIDIPropertyUniqueID, value);
    if (status) {
        // Ignore failure... not sure if this is the right thing to do or not.
    }

    // Refresh our idea of the unique ID since it may or may not have changed
    [self updateUniqueID];
}

- (NSString *)name;
{
    if (!flags.hasCachedName) {
        [cachedName release];
        cachedName = [[self stringForProperty:kMIDIPropertyName] retain];
        flags.hasCachedName = YES;
    }

    return cachedName;
}

- (void)setName:(NSString *)value;
{
    if (![value isEqualToString:[self name]]) {
        [self setString:value forProperty:kMIDIPropertyName];
        flags.hasCachedName = NO;
        // Make sure we read it back from the MIDIServer next time, just in case our change did not stick
    }
}

//
// General property access
//

- (id)allProperties;
{
    id propertyList;

    if (noErr != MIDIObjectGetProperties(objectRef, (CFPropertyListRef *)&propertyList, NO /* not deep */))
        propertyList = nil;

    return [propertyList autorelease];
}

- (NSString *)stringForProperty:(CFStringRef)property;
{
    NSString *string;

    if (noErr == MIDIObjectGetStringProperty(objectRef, property, (CFStringRef *)&string))
        return [string autorelease];
    else
        return nil;
}

- (void)setString:(NSString *)value forProperty:(CFStringRef)property;
{
    OSStatus status;

    [self checkIfPropertySetIsAllowed];

    status = MIDIObjectSetStringProperty(objectRef, property, (CFStringRef)value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set object's property '%@' to '%@' (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property, value string, and OSStatus if setting object's property fails"), property, value, status];
    }
}

- (SInt32)integerForProperty:(CFStringRef)property;
{
    OSStatus status;
    SInt32 value;

    status = MIDIObjectGetIntegerProperty(objectRef, property, &value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't get object's property '%@' (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property and OSStatus if getting object's property fails"), property, status];
    }

    return value;
}

- (void)setInteger:(SInt32)value forProperty:(CFStringRef)property;
{
    OSStatus status;

    [self checkIfPropertySetIsAllowed];

    status = MIDIObjectSetIntegerProperty(objectRef, property, value);
    if (status) {
        [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Couldn't set object's property '%@' to %ld (error %ld)", @"SnoizeMIDI", [self bundle], "exception with property, SInt32, and OSStatus if setting object's property fails"), property, status];
    }
}

//
// Other
//

- (void)checkIfPropertySetIsAllowed;
{
    // Do nothing in base class
}

- (void)invalidateCachedProperties;
{
    flags.hasCachedName = NO;
}

// TODO see if this still needs to be public
- (void)updateUniqueID;
{
    if (noErr != MIDIObjectGetIntegerProperty(objectRef, kMIDIPropertyUniqueID, &uniqueID))
        uniqueID = 0;
}

- (void)propertyDidChange:(NSString *)propertyName;
{
    // TODO I am kind of worried about this... will we still get this notification if WE are the ones who changed the values?
    
    if ([propertyName isEqualToString:(NSString *)kMIDIPropertyName]) {
        flags.hasCachedName = NO;
    } else if ([propertyName isEqualToString:(NSString *)kMIDIPropertyUniqueID]) {
        [self updateUniqueID];
    }    
}

@end



@implementation SMMIDIObject (Private)

int midiObjectOrdinalComparator(id object1, id object2, void *context)
{
    unsigned int ordinal1, ordinal2;

    ordinal1 = [object1 ordinal];
    ordinal2 = [object2 ordinal];

    if (ordinal1 > ordinal2)
        return NSOrderedDescending;
    else if (ordinal1 == ordinal2)
        return NSOrderedSame;
    else
        return NSOrderedAscending;
}

static NSMapTable *classToObjectsMapTable = NULL;
// A map table from (Class) to (NSMapTable *).
// Keys are leaf subclasses of SMMIDIObject.
// Objects are pointers to the subclass's NSMapTable from MIDIObjectRef to (SMMIDIObject *).

+ (void)privateDidLoad;
{
    OBASSERT(self == [SMMIDIObject class]);

    classToObjectsMapTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(midiClientCreated:) name:SMClientCreatedInternalNotification object:nil];
}

+ (void)midiClientCreated:(NSNotification *)notification;
{
    NSSet *leafSubclasses;
    NSEnumerator *enumerator;
    NSValue *aClassValue;
    NSNotificationCenter *center;
    SMClient *client;

    OBASSERT(self == [SMMIDIObject class]);

    // Send +initialMIDISetup to each leaf subclass of this class.    
    leafSubclasses = [self leafSubclasses];
    enumerator = [leafSubclasses objectEnumerator];
    while ((aClassValue = [enumerator nextObject])) {
        Class aClass = [aClassValue pointerValue];
        [aClass initialMIDISetup];
    }

    client = [SMClient sharedClient];
    center = [NSNotificationCenter defaultCenter];

    // Also subscribe to the object property changed notification, if it will be posted.
    // We will receive this notification and then dispatch it to the correct object.
    if ([client postsObjectPropertyChangedNotifications]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(midiObjectPropertyChanged:) name:SMClientObjectPropertyChangedNotification object:[SMClient sharedClient]];
    }

    // And subscribe to object added/removed notifications, if they will be posted.
    // We will dispatch these to the correct subclass.
    if ([client postsObjectAddedAndRemovedNotifications]) {
        [center addObserver:self selector:@selector(midiObjectWasAdded:) name:SMClientObjectAddedNotification object:client];
        [center addObserver:self selector:@selector(midiObjectWasRemoved:) name:SMClientObjectRemovedNotification object:client];
    } else {
        // Otherwise, make each subclass listen to the general "something changed" notification.
        enumerator = [leafSubclasses objectEnumerator];
        while ((aClassValue = [enumerator nextObject])) {
            Class aClass = [aClassValue pointerValue];
            [center addObserver:aClass selector:@selector(midiSetupChanged:) name:SMClientSetupChangedInternalNotification object:client];
        }
    }    
}

// TODO this is expensive -- need to look through over 700 classes. Do this only once if at all possible.
+ (NSSet *)leafSubclasses;
{
    int numClasses, newNumClasses;
    Class *classes;
    int classIndex;
    NSMutableSet *knownSubclasses;
    NSMutableSet *leafSubclasses;
    NSEnumerator *enumerator;
    NSValue *aClassValue;

    OBASSERT(self == [SMMIDIObject class]);

    // Get the whole list of classes
    numClasses = 0;
    newNumClasses = objc_getClassList(NULL, 0);
    classes = NULL;
    while (numClasses < newNumClasses) {
        numClasses = newNumClasses;
        classes = realloc(classes, sizeof(Class) * numClasses);
        newNumClasses = objc_getClassList(classes, numClasses);
    }

    // For each class:
    //    if it is a subclass of this class, add it to knownSubclasses
    knownSubclasses = [NSMutableSet set];
    for (classIndex = 0; classIndex < numClasses; classIndex++) {
        Class aClass = classes[classIndex];

        if (aClass != self && OBClassIsSubclassOfClass(aClass, self))
            [knownSubclasses addObject:[NSValue valueWithPointer:aClass]];
    }

    free(classes);

    // copy knownSubclasses to leaves
    leafSubclasses = [NSMutableSet setWithSet:knownSubclasses];

    // Then for each class in knownSubclasses,
    //    if its superclass is in knownSubclasses
    //       remove that superclass from leaves
    enumerator = [knownSubclasses objectEnumerator];
    while ((aClassValue = [enumerator nextObject])) {
        Class aClass = [aClassValue pointerValue];
        NSValue *superclassValue = [NSValue valueWithPointer:aClass->super_class];
        if ([knownSubclasses containsObject:superclassValue])
            [leafSubclasses removeObject:superclassValue];
    }
    
    // End: we are left with the correct set of leaves.
    return leafSubclasses;
}

+ (Class)subclassForObjectType:(MIDIObjectType)objectType
{
    // Go through each of our subclasses and find which one owns objects of this type.
    // TODO this is kind of inefficient; a map from type to class might be better

    NSSet *leafSubclasses;
    NSEnumerator *enumerator;
    NSValue *subclassValue;

    OBASSERT(self == [SMMIDIObject class]);

    leafSubclasses = [self leafSubclasses];
    enumerator = [leafSubclasses objectEnumerator];
    while ((subclassValue = [enumerator nextObject])) {
        Class subclass = [subclassValue pointerValue];

        if ([subclass midiObjectType] == objectType)
            return subclass;
    }

    return Nil;
}

//
// Notifications that objects have changed
//

+ (void)midiObjectPropertyChanged:(NSNotification *)notification;
{
    MIDIObjectRef ref;
    MIDIObjectType objectType;
    NSString *propertyName;
    Class subclass;
    SMMIDIObject *object;
        
    OBASSERT(self == [SMMIDIObject class]);

    ref = [[[notification userInfo] objectForKey:SMClientObjectPropertyChangedObject] pointerValue];
    objectType = [[[notification userInfo] objectForKey:SMClientObjectPropertyChangedType] intValue];
    propertyName = [[notification userInfo] objectForKey:SMClientObjectPropertyChangedName];

    subclass = [self subclassForObjectType:objectType];
    object = [subclass objectWithObjectRef:ref];
    [object propertyDidChange:propertyName];
}

+ (void)midiObjectWasAdded:(NSNotification *)notification;
{
    MIDIObjectRef ref;
    MIDIObjectType objectType;
    Class subclass;

    OBASSERT(self == [SMMIDIObject class]);

    ref = [[[notification userInfo] objectForKey:SMClientObjectAddedOrRemovedChild] pointerValue];
    OBASSERT(ref != NULL);
    objectType = [[[notification userInfo] objectForKey:SMClientObjectAddedOrRemovedChildType] intValue];

    subclass = [self subclassForObjectType:objectType];
    if (subclass) {
        // We might already have this object. Check and see.
        if (![subclass objectWithObjectRef:ref])
            [subclass immediatelyAddObjectWithObjectRef:ref];
    }
}

+ (void)midiObjectWasRemoved:(NSNotification *)notification;
{
    MIDIObjectRef ref;
    MIDIObjectType objectType;
    Class subclass;

    OBASSERT(self == [SMMIDIObject class]);

    ref = [[[notification userInfo] objectForKey:SMClientObjectAddedOrRemovedChild] pointerValue];
    OBASSERT(ref != NULL);
    objectType = [[[notification userInfo] objectForKey:SMClientObjectAddedOrRemovedChildType] intValue];

    subclass = [self subclassForObjectType:objectType];
    [subclass removeObjectWithObjectRef:ref];
    // Any of the objects' ordinals may have changed, so refresh them
    [subclass refreshObjectOrdinals];
}

//
// Methods to be used in SMMIDIObject subclasses only
//

+ (NSMapTable *)midiObjectMapTable;
{
    OBASSERT(self != [SMMIDIObject class]);

    return NSMapGet(classToObjectsMapTable, self);
}

+ (void)initialMIDISetup;
{
    ItemCount objectIndex, objectCount;
    NSMapTable *newMapTable;

    OBASSERT(self != [SMMIDIObject class]);

    objectCount = [self midiObjectCount];

    newMapTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, objectCount);
    NSMapInsertKnownAbsent(classToObjectsMapTable, self, newMapTable);

    // Iterate through the new MIDIObjectRefs and add a wrapper object for each
    for (objectIndex = 0; objectIndex < objectCount; objectIndex++) {
        MIDIObjectRef anObjectRef;

        anObjectRef = [self midiObjectAtIndex:objectIndex];
        if (anObjectRef == NULL)
            continue;

        [self addObjectWithObjectRef:anObjectRef ordinal:objectIndex];
    }
}

+ (void)addObjectWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(unsigned int)anOrdinal;
{
    SMMIDIObject *object;

    OBASSERT(self != [SMMIDIObject class]);
    OBASSERT(anObjectRef != NULL);

    object = [[self alloc] initWithObjectRef:anObjectRef ordinal:anOrdinal];
    if (object) {
        NSMapTable *mapTable = [self midiObjectMapTable];
        OBASSERT(mapTable != NULL);

        NSMapInsertKnownAbsent(mapTable, anObjectRef, object);
        [object release];
    }
}

+ (void)removeObjectWithObjectRef:(MIDIObjectRef)anObjectRef;
{
    NSMapTable *mapTable = [self midiObjectMapTable];

    OBASSERT(self != [SMMIDIObject class]);
    OBASSERT(mapTable != NULL);

    NSMapRemove(mapTable, anObjectRef);
}

+ (void)refreshObjectOrdinals;
{
    ItemCount index, count;

    OBASSERT(self != [SMMIDIObject class]);

    count = [self midiObjectCount];
    for (index = 0; index < count; index++) {
        MIDIObjectRef ref = [self midiObjectAtIndex:index];
        [[self objectWithObjectRef:ref] setOrdinal:index];
    }
}

+ (void)midiSetupChanged:(NSNotification *)notification;
{
    OBASSERT(self != [SMMIDIObject class]);

    // TODO
    // Figure out how this should work... similar to what we used to do.

    // Also, on all surviving objects, we need to invalidate cached properties.
}

@end
