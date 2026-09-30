#import "GDLevelCatalog.h"
@interface GDLevel ()
@property(nonatomic) NSInteger levelID, target, parShots, parScore;
@property(nonatomic, copy) NSString *title;
@property(nonatomic) GDObjective objective;
@property(nonatomic) GDColor objectiveColor;
@property(nonatomic) NSTimeInterval pressureInterval, parTime;
@property(nonatomic) NSUInteger seed;
@property(nonatomic, copy) NSArray<NSArray<NSString *> *> *layouts;
@property(nonatomic, copy) NSArray<NSNumber *> *startingEnergy;
@end
@implementation GDLevel
@end
@implementation GDLevelCatalog
+ (NSArray<GDLevel *> *)levels {
    static NSArray *catalog;
    @synchronized(self) { if(!catalog) {
        NSString *json=
#include "GDLevelsData.inc"
        ;
        NSDictionary *data=[NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        NSMutableArray *result=[NSMutableArray new];NSDictionary *types=@{@"clear":@(GDObjectiveClear),@"collect":@(GDObjectiveCollect),@"fall":@(GDObjectiveFall),@"survive":@(GDObjectiveSurvive)};
        for(NSDictionary *entry in data[@"levels"]) { GDLevel *level=[GDLevel new];level.levelID=[entry[@"id"] integerValue];level.title=entry[@"title"];level.objective=[types[entry[@"objective"]] integerValue];level.objectiveColor=[entry[@"color"] integerValue];level.target=[entry[@"target"] integerValue];level.parShots=[entry[@"parShots"] integerValue];level.parTime=[entry[@"parTime"] doubleValue];level.parScore=[entry[@"parScore"] integerValue];level.pressureInterval=[entry[@"pressureInterval"] doubleValue];level.seed=[entry[@"seed"] unsignedIntegerValue];level.layouts=entry[@"layouts"];level.startingEnergy=entry[@"startingEnergy"];[result addObject:level]; }
        catalog=[result copy];
    }} return catalog;
}
+ (GDLevel *)levelForID:(NSInteger)levelID { NSArray *levels=self.levels;return levelID>=1&&levelID<=(NSInteger)levels.count?levels[levelID-1]:nil; }
@end
