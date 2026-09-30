#import "GDSettings.h"
#if !GD_SETTINGS_TESTS
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
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
- (void)setSoundEffectsEnabled:(BOOL)value { [self.defaults setBool:value forKey:GDSoundKey]; }
- (void)playFeedback:(GDFeedbackType)feedback {
#if !GD_SETTINGS_TESTS
    if(feedback<GDFeedbackTap || feedback>GDFeedbackError) return;
    if(self.soundEffectsEnabled) {
        static SystemSoundID sounds[6];
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSArray<NSString *> *names=@[@"tap",@"shot",@"match",@"skill",@"game_over",@"error"];
            for(NSUInteger i=0;i<names.count;i++) {
                NSURL *url=[NSBundle.mainBundle URLForResource:names[i] withExtension:@"wav"];
                OSStatus status=url?AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &sounds[i]):kAudioServicesSystemSoundUnspecifiedError;
                if(status!=kAudioServicesNoError) NSLog(@"Could not load sound %@ (%d)",names[i],(int)status);
            }
        });
        if(sounds[feedback]) AudioServicesPlaySystemSound(sounds[feedback]);
#if DEBUG
        if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-feedback"]) NSLog(@"QA sound feedback=%ld id=%u",(long)feedback,(unsigned int)sounds[feedback]);
#endif
    }
    if(self.hapticsEnabled) {
        if(feedback==GDFeedbackError || feedback==GDFeedbackGameOver) {
            UINotificationFeedbackGenerator *generator=[UINotificationFeedbackGenerator new];
            [generator notificationOccurred:feedback==GDFeedbackError?UINotificationFeedbackTypeWarning:UINotificationFeedbackTypeError];
        } else {
            UIImpactFeedbackGenerator *generator=[[UIImpactFeedbackGenerator alloc] initWithStyle:feedback==GDFeedbackTap?UIImpactFeedbackStyleLight:UIImpactFeedbackStyleSoft];
            [generator impactOccurred];
        }
    }
#endif
}
@end
