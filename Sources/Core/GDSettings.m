#import "GDSettings.h"
#if !GD_SETTINGS_TESTS
#import <UIKit/UIKit.h>
#import "GDAudioFeedback.h"
#endif

static NSString * const GDAimKey = @"GummySettingsAimGuide";
static NSString * const GDHapticsKey = @"GummySettingsHaptics";
static NSString * const GDSoundKey = @"GummySettingsSoundEffects";

@interface GDSettings ()
@property(nonatomic) NSUserDefaults *defaults;
@end

@implementation GDSettings
+ (instancetype)sharedSettings {
    static GDSettings *settings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ settings=[[self alloc] initWithDefaults:NSUserDefaults.standardUserDefaults]; });
    return settings;
}
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    if((self=[super init])) {
        _defaults=defaults;
        [defaults registerDefaults:@{GDAimKey:@YES, GDHapticsKey:@YES, GDSoundKey:@YES}];
    }
    return self;
}
- (BOOL)aimGuideEnabled { return [self.defaults boolForKey:GDAimKey]; }
- (BOOL)hapticsEnabled { return [self.defaults boolForKey:GDHapticsKey]; }
- (BOOL)soundEffectsEnabled { return [self.defaults boolForKey:GDSoundKey]; }
- (void)setAimGuideEnabled:(BOOL)value { [self.defaults setBool:value forKey:GDAimKey]; }
- (void)setHapticsEnabled:(BOOL)value { [self.defaults setBool:value forKey:GDHapticsKey]; }
- (void)setSoundEffectsEnabled:(BOOL)value {
    [self.defaults setBool:value forKey:GDSoundKey];
#if !GD_SETTINGS_TESTS
    if(!value) [GDAudioFeedback.sharedPlayer stop];
#endif
}
- (void)playFeedback:(GDFeedbackType)feedback { [self playFeedback:feedback intensity:.5]; }
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity {
#if !GD_SETTINGS_TESTS
    if(feedback<GDFeedbackTap || feedback>GDFeedbackWin) return;
    if(self.soundEffectsEnabled) [GDAudioFeedback.sharedPlayer playFeedback:feedback intensity:intensity];
    if(self.hapticsEnabled) {
        if(feedback==GDFeedbackError || feedback==GDFeedbackGameOver || feedback==GDFeedbackWin) {
            UINotificationFeedbackGenerator *generator=[UINotificationFeedbackGenerator new];
            [generator notificationOccurred:feedback==GDFeedbackWin?UINotificationFeedbackTypeSuccess:(feedback==GDFeedbackError?UINotificationFeedbackTypeWarning:UINotificationFeedbackTypeError)];
        } else {
            UIImpactFeedbackGenerator *generator=[[UIImpactFeedbackGenerator alloc] initWithStyle:feedback==GDFeedbackTap?UIImpactFeedbackStyleLight:UIImpactFeedbackStyleSoft];
            [generator impactOccurred];
        }
    }
#endif
}
@end
