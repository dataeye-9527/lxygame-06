#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GDFeedbackType) {
    GDFeedbackTap, GDFeedbackShot, GDFeedbackMatch,
    GDFeedbackSkill, GDFeedbackGameOver, GDFeedbackError,
    GDFeedbackFall, GDFeedbackCombo, GDFeedbackFreeze, GDFeedbackBlast,
    GDFeedbackSweep, GDFeedbackWild, GDFeedbackReady, GDFeedbackWin
};

@interface GDSettings : NSObject
@property(nonatomic) BOOL aimGuideEnabled;
@property(nonatomic) BOOL hapticsEnabled;
@property(nonatomic) BOOL soundEffectsEnabled;
+ (instancetype)sharedSettings;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (void)playFeedback:(GDFeedbackType)feedback;
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity;
@end
NS_ASSUME_NONNULL_END
