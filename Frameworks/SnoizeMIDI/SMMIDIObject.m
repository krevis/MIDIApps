#import "SMMIDIObject.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "SMClient.h"
#import "SMEndpoint.h"
#import "SMMIDIObject-Private.h"


@interface SMMIDIObject (Private)

static int midiObjectOrdinalComparator(id object1, id object2, void *context);

// Methods to be used on SMMIDIObject itself, not subclasses

+ (void)privateDidLoad;
+ (void)midiClientCreated:(NSNotification *)notification;
+ (NSSet *)leafSubclasses;
+ (Class)subclassForObjectType:(MIDIObjectType)objectType;

+ (BOOL)isUniqueIDInUse:(MIDIUniqueID)proposedUniqueID;

+ (void)midiObjectPropertyChanged:(NSNotification *)notification;
+ (void)midiObjectWasAdded:(NSNotification *)notification;
+ (void)midiObjectWasRemoved:(NSNotification *)notification;

// Methods to be used on subclasses of SMMIDIObject, not SMMIDIObject itself

+ (NSMapTable *)midiObjectMapTable;

+ (SMMIDIObject *)addObjectWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(unsigned int)anOrdinal;
+ (void)removeObjectWithObjectRef:(MIDIObjectRef)anObjectRef;

+ (void)refreshObjectOrdinals;

+ (void)midiSetupChanged:(NSNotification *)notification;

+ (void)postObjectListChangedNotification;

- (void)updateUniqueID;

- (void)postRemovedNotification;
- (void)postReplacedNotificationWithReplacement:(SMMIDIObject *)replacement;

@end


@implementation SMMIDIObject

NSString *SMMIDIObjectsAppearedNotification = @"SMMIDIObjectsAppearedNotification";
NSString *SMMIDIObjectsThatAppeared = @"SMMIDIObjectsThatAppeared";
NSString *SMMIDIObjectDisappearedNotification = @"SMMIDIObjectDisappearedNotification";
NSString *SMMIDIObjectWasReplacedNotification = @"SMMIDIObjectWasReplacedNotification";
NSString *SMMIDIObjectReplacement = @"SMMIDIObjectReplacement";
NSString *SMMIDIObjectListChangedNotification = @"SMMIDIObjectListChangedNotification";


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
// Generate a new unique ID
//

+ (MIDIUniqueID)generateNewUniqueID;
{
    static MIDIUniqueID sequence = 0;
    MIDIUniqueID proposed;
    BOOL foundUnique = NO;

    while (!foundUnique) {
        // We could get fancy, but just using the current time is likely to work just fine.
        // Add a sequence number in case this method is called more than once within a second.
        proposed = time(NULL);
        proposed += sequence;
        sequence++;

        // Make sure this uniqueID is not in use, just in case.
        foundUnique = ![self isUniqueIDInUse:proposed];
    }

    return proposed;
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

- (BOOL)setUniqueID:(MIDIUniqueID)value;
{
    if (value == uniqueID)
        return YES;

    [self checkIfPropertySetIsAllowed];

    MIDIObjectSetIntegerProperty(objectRef, kMIDIPropertyUniqueID, value);
    // Ignore the error code. We're going to check if our change stuck, either way.

    // Refresh our idea of the unique ID since it may or may not have changed
    [self updateUniqueID];

    return (uniqueID == value);
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

- (BOOL)isOffline;
{
    return [self integerForProperty:kMIDIPropertyOffline];
}

- (BOOL)isOnline;
{
    return ![self isOffline];
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

- (void)propertyDidChange:(NSString *)propertyName;
{
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

+ (NSSet *)leafSubclasses;
{
    static NSMutableSet *sLeafSubclasses = nil;
    
    // This is expensive -- we need to look through over 700 classes--so we do it only once.
    if (!sLeafSubclasses) {
        int numClasses, newNumClasses;
        Class *classes;
        int classIndex;
        NSMutableSet *knownSubclasses;
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
        sLeafSubclasses = [[NSMutableSet alloc] initWithSet:knownSubclasses];
    
        // Then for each class in knownSubclasses,
        //    if its superclass is in knownSubclasses
        //       remove that superclass from leaves
        enumerator = [knownSubclasses objectEnumerator];
        while ((aClassValue = [enumerator nextObject])) {
            Class aClass = [aClassValue pointerValue];
            NSValue *superclassValue = [NSValue valueWithPointer:aClass->super_class];
            if ([knownSubclasses containsObject:superclassValue])
                [sLeafSubclasses removeObject:superclassValue];
        }
        
        // End: we are left with the correct set of leaves.
    }

    return sLeafSubclasses;
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
// Unique IDs
//

+ (BOOL)isUniqueIDInUse:(MIDIUniqueID)proposedUniqueID;
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_2
{
    MIDIObjectRef object = NULL;
    MIDIObjectType type;

    MIDIObjectFindByUniqueID(proposedUniqueID, &object, &type);
    return (object != NULL);
}
#else
{
    static BOOL lookedForFunction = NO;
    static OSStatus (*midiObjectFindByUniqueIDFuncPtr)(MIDIUniqueID, MIDIObjectRef *, MIDIObjectType *) = NULL;

    if (!lookedForFunction) {
        midiObjectFindByUniqueIDFuncPtr = [[SMClient sharedClient] coreMIDIFunctionNamed:@"MIDIObjectFindByUniqueID"];
        lookedForFunction = YES;
    }

    if (midiObjectFindByUniqueIDFuncPtr) {
        MIDIObjectRef object;
        MIDIObjectType type;

        midiObjectFindByUniqueIDFuncPtr(proposedUniqueID, &object, &type);
        return (object != NULL);
    } else {
        // This search is not as complete as it could be, but it'll have to do.
        // We're only going to set unique IDs on virtual endpoints, anyway.
        return ([SMSourceEndpoint sourceEndpointWithUniqueID:proposedUniqueID] != nil || [SMDestinationEndpoint destinationEndpointWithUniqueID:proposedUniqueID] != nil);
    }
}
#endif

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
    SMMIDIObject *object;

    OBASSERT(self == [SMMIDIObject class]);

    ref = [[[notification userInfo] objectForKey:SMClientObjectAddedOrRemovedChild] pointerValue];
    OBASSERT(ref != NULL);
    objectType = [[[notification userInfo] objectForKey:SMClientObjectAddedOrRemovedChildType] intValue];

    subclass = [self subclassForObjectType:objectType];
    if ((object = [subclass objectWithObjectRef:ref]))
        [subclass immediatelyRemoveObject:object];
}

//
// Methods to be used on subclasses of SMMIDIObject, not SMMIDIObject itself
//

+ (NSMapTable *)midiObjectMapTable;
{
    OBASSERT(self != [SMMIDIObject class]);

    return NSMapGet(classToObjectsMapTable, self);
}

+ (SMMIDIObject *)addObjectWithObjectRef:(MIDIObjectRef)anObjectRef ordinal:(unsigned int)anOrdinal;
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

    return object;
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

    [self refreshAllObjects];
}

+ (void)postObjectListChangedNotification;
{
    OBASSERT(self != [SMMIDIObject class]);

    [[NSNotificationCenter defaultCenter] postNotificationName:SMMIDIObjectListChangedNotification object:self];
}

- (void)updateUniqueID;
{
    if (noErr != MIDIObjectGetIntegerProperty(objectRef, kMIDIPropertyUniqueID, &uniqueID))
        uniqueID = 0;
}

- (void)postRemovedNotification;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMIDIObjectDisappearedNotification object:self];
}

- (void)postReplacedNotificationWithReplacement:(SMMIDIObject *)replacement;
{
    NSDictionary *userInfo;

    OBASSERT(replacement != NULL);
    userInfo = [NSDictionary dictionaryWithObject:replacement forKey:SMMIDIObjectReplacement];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMIDIObjectWasReplacedNotification object:self userInfo:userInfo];
}

@end


@implementation SMMIDIObject (FrameworkPrivate)

//
// Methods which should rightly be private to this file only, but need to be called
// by other SMMIDIObject subclasses.
// Declared in SMMIDIObject-Private.h.

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

+ (SMMIDIObject *)immediatelyAddObjectWithObjectRef:(MIDIObjectRef)anObjectRef;
{
    SMMIDIObject *theObject;

    // Use a default ordinal to start
    theObject = [self addObjectWithObjectRef:anObjectRef ordinal:0];
    // Any of the objects' ordinals may have changed, so refresh them
    [self refreshObjectOrdinals];
    // And post a notification that the object list has changed
    [self postObjectListChangedNotification];
    
    return theObject;
}

+ (void)immediatelyRemoveObject:(SMMIDIObject *)object;
{
    [self removeObjectWithObjectRef:[object objectRef]];
    // Any of the objects' ordinals may have changed, so refresh them
    [self refreshObjectOrdinals];
    // And post a notification that the object list has changed
    [self postObjectListChangedNotification];
}

+ (void)refreshAllObjects;
{
    NSMapTable *oldMapTable, *newMapTable;
    ItemCount objectIndex, objectCount;
    NSMutableArray *removedObjects, *replacedObjects, *replacementObjects, *addedObjects;

    OBASSERT(self != [SMMIDIObject class]);

    objectCount = [self midiObjectCount];

    oldMapTable = [self midiObjectMapTable];
    newMapTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, objectCount);

    // We start out assuming all objects have been removed, none have been replaced.
    // As we find out otherwise, we remove some endpoints from removedObjects,
    // and add some to replacedObjects.
    removedObjects = [NSMutableArray arrayWithArray:[self allObjects]];
    replacedObjects = [NSMutableArray array];
    replacementObjects = [NSMutableArray array];
    addedObjects = [NSMutableArray array];

    // Iterate through the new objectRefs.
    for (objectIndex = 0; objectIndex < objectCount; objectIndex++) {
        MIDIObjectRef anObjectRef;
        SMMIDIObject *object;

        anObjectRef = [self midiObjectAtIndex:objectIndex];
        if (anObjectRef == NULL)
            continue;

        if ((object = [self objectWithObjectRef:anObjectRef])) {
            // This objectRef existed previously.
            [removedObjects removeObjectIdenticalTo:object];
            // It's possible that its uniqueID changed, though.
            [object updateUniqueID];
            // And its ordinal may also have changed.
            [object setOrdinal:objectIndex];
        } else {
            SMMIDIObject *replacedObject;

            // This objectRef did not previously exist, so create a new object for it.
            // (Don't add it to the map table, though.)
            object = [[[self alloc] initWithObjectRef:anObjectRef ordinal:objectIndex] autorelease];
            if (object) {
                // If the new object has the same uniqueID as an old object, remember it.
                if ((replacedObject = [self objectWithUniqueID:[object uniqueID]])) {
                    [replacedObjects addObject:replacedObject];
                    [replacementObjects addObject:object];
                    [removedObjects removeObjectIdenticalTo:replacedObjects];
                } else {
                    [addedObjects addObject:object];
                }
            }
        }

        if (object)
            NSMapInsert(newMapTable, anObjectRef, object);
    }

    // Now replace the old set of objects with the new one.
    if (oldMapTable)
        NSFreeMapTable(oldMapTable);
    NSMapInsert(classToObjectsMapTable, self, newMapTable);

    // Make the new group of objects invalidate their cached properties (names and such).
    [[self allObjects] makeObjectsPerformSelector:@selector(invalidateCachedProperties)];

    // Now everything is in place for the new regime.
    // First, post specific notifications for added/removed/replaced objects.
    if ([addedObjects count] > 0) {
        NSDictionary *userInfo;

        userInfo = [NSDictionary dictionaryWithObject:addedObjects forKey:SMMIDIObjectsThatAppeared];
        [[NSNotificationCenter defaultCenter] postNotificationName:SMMIDIObjectsAppearedNotification object:self userInfo:userInfo];
    }
    
    [removedObjects makeObjectsPerformSelector:@selector(postRemovedNotification)];

    objectIndex = [replacedObjects count];
    while (objectIndex--)
        [[replacedObjects objectAtIndex:objectIndex] postReplacedNotificationWithReplacement:[replacementObjects objectAtIndex:objectIndex]];

    // Then, post a general notification that the list of objects for this subclass has changed (if it has).
    if ([addedObjects count] > 0 || [removedObjects count] > 0 || [replacedObjects count] > 0)
        [self postObjectListChangedNotification];
}

@end
