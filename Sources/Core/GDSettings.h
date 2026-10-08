#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GDFeedbackType) {
    GDFeedbackTap, GDFeedbackShot, GDFeedbackMatch,
    GDFeedbackSkill, GDFeedbackGameOver, GDFeedbackError,
    GDFeedbackFall, GDFeedbackCombo, GDFeedbackFreeze, GDFeedbackBlast,
    GDFeedbackSweep, GDFeedbackWild, GDFeedbackReady, GDFeedbackWin, GDFeedbackBlastReady
};

@interface GDSettings : NSObject
@property(nonatomic) BOOL aimGuideEnabled;
@property(nonatomic) BOOL hapticsEnabled;
@property(nonatomic) BOOL soundEffectsEnabled;
@property(nonatomic) BOOL musicEnabled;
+ (instancetype)sharedSettings;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (void)playFeedback:(GDFeedbackType)feedback;
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity;
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity color:(NSInteger)color;
@end
NS_ASSUME_NONNULL_END
