#import "GDProgressStore.h"
#import "GDLevelCatalog.h"
@interface GDProgressStore ()
@property(nonatomic) NSUserDefaults *defaults;
@end
@implementation GDProgressStore
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults { if((self=[super init]))_defaults=defaults;return self; }
- (NSDictionary *)data { id d=[self.defaults objectForKey:@"GDCampaignProgress"];return [d isKindOfClass:NSDictionary.class]&&[d[@"format"] isKindOfClass:NSNumber.class]&&[d[@"format"] integerValue]==1?d:@{}; }
- (NSDictionary *)entry:(NSInteger)levelID { id levels=self.data[@"levels"];id entry=[levels isKindOfClass:NSDictionary.class]?levels[[NSString stringWithFormat:@"%ld",(long)levelID]]:nil;return [entry isKindOfClass:NSDictionary.class]&&[entry[@"stars"] isKindOfClass:NSNumber.class]&&[entry[@"score"] isKindOfClass:NSNumber.class]?entry:@{}; }
- (NSInteger)unlockedLevel { return MAX(1,MIN((NSInteger)GDLevelCatalog.levels.count,([self.data[@"unlocked"] isKindOfClass:NSNumber.class]?[self.data[@"unlocked"] integerValue]:1))); }
- (BOOL)isLevelUnlocked:(NSInteger)levelID { return levelID>=1&&levelID<=self.unlockedLevel; }
- (NSInteger)bestStarsForLevel:(NSInteger)levelID { return MAX(0,MIN(3,[[self entry:levelID][@"stars"] integerValue])); }
- (NSInteger)bestScoreForLevel:(NSInteger)levelID { return MAX(0,[[self entry:levelID][@"score"] integerValue]); }
- (NSInteger)totalStars { NSInteger total=0;for(GDLevel *level in GDLevelCatalog.levels)total+=[self bestStarsForLevel:level.levelID];return total; }
- (void)recordWinForLevel:(NSInteger)levelID stars:(NSInteger)stars score:(NSInteger)score {
    if(![GDLevelCatalog levelForID:levelID]||stars<1||stars>3||score<0)return;
    @synchronized(self.defaults) { NSMutableDictionary *levels=[self.data[@"levels"] isKindOfClass:NSDictionary.class]?[self.data[@"levels"] mutableCopy]:[NSMutableDictionary new];levels[[NSString stringWithFormat:@"%ld",(long)levelID]]=@{@"stars":@(MAX(stars,[self bestStarsForLevel:levelID])),@"score":@(MAX(score,[self bestScoreForLevel:levelID]))};NSInteger unlocked=MAX(self.unlockedLevel,MIN((NSInteger)GDLevelCatalog.levels.count,levelID+1));[self.defaults setObject:@{@"format":@1,@"unlocked":@(unlocked),@"levels":levels} forKey:@"GDCampaignProgress"]; }
}
@end
