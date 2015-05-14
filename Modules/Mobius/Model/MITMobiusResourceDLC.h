#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "MITManagedObject.h"
#import "MITMappedObject.h"

@class MITMobiusResource;

@interface MITMobiusResourceDLC : MITManagedObject <MITMappedObject>

@property (nonatomic, retain) NSString * code;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) MITMobiusResource *resource;

@end