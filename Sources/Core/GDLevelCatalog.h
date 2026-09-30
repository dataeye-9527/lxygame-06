#import "GDEngine.h"
NS_ASSUME_NONNULL_BEGIN
@interface GDLevel : NSObject
@property(nonatomic, readonly) NSInteger levelID;
@property(nonatomic, readonly) NSString *title;
@property(nonatomic, readonly) GDObjective objective;
@property(nonatomic, readonly) GDColor objectiveColor;
@property(nonatomic, readonly) NSInteger target, parShots, parScore;
@property(nonatomic, readonly) NSTimeInterval pressureInterval, parTime;
@property(nonatomic, readonly) NSUInteger seed;
@property(nonatomic, readonly) NSArray<NSArray<NSString *> *> *layouts;
@property(nonatomic, readonly) NSArray<NSNumber *> *startingEnergy;
@end
@interface GDLevelCatalog : NSObject
+ (NSArray<GDLevel *> *)levels;
+ (nullable GDLevel *)levelForID:(NSInteger)levelID;
@end
NS_ASSUME_NONNULL_END
