#import <Foundation/Foundation.h>
#import "GDSettings.h"

NS_ASSUME_NONNULL_BEGIN
/// Quiet, bounded local effect playback. Ambient audio respects the silent switch.
@interface GDAudioFeedback : NSObject
+ (instancetype)sharedPlayer;
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity;
- (void)stop;
#if DEBUG
- (void)startQAPlaybackTour;
#endif
@end
NS_ASSUME_NONNULL_END
