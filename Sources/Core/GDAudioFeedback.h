#import <Foundation/Foundation.h>
#import "GDSettings.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GDMusicMode) { GDMusicSilent, GDMusicRelaxed, GDMusicDanger };
/// Original loop music and bounded effects. Ambient audio respects the silent switch.
@interface GDAudioFeedback : NSObject
+ (instancetype)sharedPlayer;
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity;
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity color:(NSInteger)color;
- (void)setMusicMode:(GDMusicMode)mode;
- (void)pauseMusic;
- (void)resumeMusic;
- (void)refreshMusicPreference;
- (void)stopEffects;
- (void)stop;
#if DEBUG
- (void)startQAPlaybackTour;
- (NSDictionary *)qaAudioState;
#endif
@end
NS_ASSUME_NONNULL_END
