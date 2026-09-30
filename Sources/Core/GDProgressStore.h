#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface GDProgressStore : NSObject
@property(nonatomic, readonly) NSInteger unlockedLevel, totalStars;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (NSInteger)bestStarsForLevel:(NSInteger)levelID;
- (NSInteger)bestScoreForLevel:(NSInteger)levelID;
- (BOOL)isLevelUnlocked:(NSInteger)levelID;
- (void)recordWinForLevel:(NSInteger)levelID stars:(NSInteger)stars score:(NSInteger)score;
@end
NS_ASSUME_NONNULL_END
