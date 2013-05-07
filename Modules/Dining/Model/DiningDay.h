#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class HouseVenue;
@class DiningMeal;

@interface DiningDay : NSManagedObject

@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSString * message;
@property (nonatomic, retain) NSOrderedSet *meals;
@property (nonatomic, retain) HouseVenue *houseVenue;

+ (DiningDay *)newDayWithDictionary:(NSDictionary *)dict;
- (NSString *)allHoursSummary;
- (DiningMeal *)mealForDate:(NSDate *)date;
- (DiningMeal *)bestMealForDate:(NSDate *)date;

@end

@interface DiningDay (CoreDataGeneratedAccessors)

- (void)insertObject:(NSManagedObject *)value inMealsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromMealsAtIndex:(NSUInteger)idx;
- (void)insertMeals:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeMealsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInMealsAtIndex:(NSUInteger)idx withObject:(NSManagedObject *)value;
- (void)replaceMealsAtIndexes:(NSIndexSet *)indexes withMeals:(NSArray *)values;
- (void)addMealsObject:(NSManagedObject *)value;
- (void)removeMealsObject:(NSManagedObject *)value;
- (void)addMeals:(NSOrderedSet *)values;
- (void)removeMeals:(NSOrderedSet *)values;
@end
