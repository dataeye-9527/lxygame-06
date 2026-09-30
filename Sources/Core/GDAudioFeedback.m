#import "GDAudioFeedback.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface GDAudioVoice : NSObject
@property(nonatomic) AVAudioPlayer *player;
@property(nonatomic) NSInteger priority;
@end
@implementation GDAudioVoice
@end

@interface GDAudioFeedback ()
@property(nonatomic) NSMutableArray<GDAudioVoice *> *voices;
@property(nonatomic) NSMutableDictionary<NSString *, NSData *> *clips;
@property(nonatomic) NSMutableDictionary<NSNumber *, NSNumber *> *lastPlayed;
@property(nonatomic) NSUInteger variation;
@property(nonatomic) BOOL sessionReady;
@end

@implementation GDAudioFeedback
+ (instancetype)sharedPlayer {
    static GDAudioFeedback *player; static dispatch_once_t once;
    dispatch_once(&once, ^{ player=[self new]; }); return player;
}
- (instancetype)init {
    if((self=[super init])) {
        _voices=[NSMutableArray array]; _clips=[NSMutableDictionary dictionary]; _lastPlayed=[NSMutableDictionary dictionary];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgrounded:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}
- (void)backgrounded:(NSNotification *)notification { [self stop]; }
- (void)interrupted:(NSNotification *)notification {
    if([notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan) [self stop];
    self.sessionReady=NO;
}
- (void)stop { for(GDAudioVoice *voice in self.voices) [voice.player stop]; [self.voices removeAllObjects]; [self.lastPlayed removeAllObjects]; }
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity {
    if(feedback<GDFeedbackTap || feedback>GDFeedbackWin || UIApplication.sharedApplication.applicationState==UIApplicationStateBackground) return;
    static NSArray<NSString *> *names; static dispatch_once_t once;
    dispatch_once(&once, ^{ names=@[@"tap",@"shot",@"match",@"skill",@"game_over",@"error",@"fall",@"combo",@"freeze",@"blast",@"sweep",@"wild",@"ready",@"win"]; });
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    NSNumber *key=@(feedback);
    if(now-self.lastPlayed[key].doubleValue < (feedback==GDFeedbackTap?.045:.06)) return;
    NSInteger priority=(feedback==GDFeedbackTap?0:(feedback==GDFeedbackShot?1:((feedback==GDFeedbackMatch||feedback==GDFeedbackFall)?2:3)));
    if(feedback==GDFeedbackGameOver || feedback==GDFeedbackWin) { [self stop]; priority=4; }
    NSMutableArray *finished=[NSMutableArray array];
    for(GDAudioVoice *voice in self.voices) if(!voice.player.playing) [finished addObject:voice];
    [self.voices removeObjectsInArray:finished];
    // A dedicated skill or combo replaces the generic tap fired by its button.
    if(priority>=3) {
        NSMutableArray *quiet=[NSMutableArray array];
        for(GDAudioVoice *voice in self.voices) if(voice.priority==0){ [voice.player stop]; [quiet addObject:voice]; }
        [self.voices removeObjectsInArray:quiet];
    }
    if(self.voices.count>=3) {
        GDAudioVoice *lowest=self.voices.firstObject;
        for(GDAudioVoice *voice in self.voices) if(voice.priority<lowest.priority) lowest=voice;
        if(priority<lowest.priority) return;
        [lowest.player stop]; [self.voices removeObject:lowest];
    }
    if(!self.sessionReady) {
        NSError *error=nil;
        AVAudioSession *session=AVAudioSession.sharedInstance;
        if(![session setCategory:AVAudioSessionCategoryAmbient error:&error] || ![session setActive:YES error:&error]) { NSLog(@"Audio session unavailable: %@",error); return; }
        self.sessionReady=YES;
    }
    NSString *name=names[feedback];
    self.variation++;
    if(feedback==GDFeedbackMatch && self.variation%2==0) name=@"match_alt";
    NSData *data=self.clips[name];
    if(!data) {
        NSURL *url=[NSBundle.mainBundle URLForResource:name withExtension:@"wav"];
        NSError *error=nil;
        data=url?[NSData dataWithContentsOfURL:url options:0 error:&error]:nil;
        if(!data) { NSLog(@"Could not load sound %@: %@",name,error?:@"missing bundled clip"); return; }
        self.clips[name]=data;
    }
    NSError *error=nil;
    AVAudioPlayer *player=[[AVAudioPlayer alloc] initWithData:data error:&error];
    if(!player) { NSLog(@"Could not decode sound %@: %@",name,error); return; }
    CGFloat level=isfinite(intensity)?MAX(0,MIN(1,intensity)):.5;
    player.volume=(feedback==GDFeedbackTap?.40:.35+.1*level);
    player.enableRate=YES;
    player.rate=(feedback==GDFeedbackShot||feedback==GDFeedbackMatch)?(.96+.02*(self.variation%5)):1;
    [player prepareToPlay];
    if(![player play]) { NSLog(@"Could not play sound %@",name); return; }
    GDAudioVoice *voice=[GDAudioVoice new]; voice.player=player; voice.priority=priority; [self.voices addObject:voice];
    self.lastPlayed[key]=@(now);
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-feedback"]) NSLog(@"QA sound clip=%@ feedback=%ld playing=%d volume=%.2f rate=%.2f voices=%lu",name,(long)feedback,player.playing,player.volume,player.rate,(unsigned long)self.voices.count);
#endif
}
#if DEBUG
- (void)startQAPlaybackTour {
    BOOL original=GDSettings.sharedSettings.soundEffectsEnabled;
    GDSettings.sharedSettings.soundEffectsEnabled=YES;
    NSLog(@"QA audio tour begin");
    for(NSInteger i=0;i<=GDFeedbackWin;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((1+i*.9)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [GDSettings.sharedSettings playFeedback:i intensity:.8]; });
    NSTimeInterval end=1+(GDFeedbackWin+1)*.9;
    for(NSInteger i=0;i<16;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((end+i*.025)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [GDSettings.sharedSettings playFeedback:(GDFeedbackType)(GDFeedbackFall+i%6) intensity:1]; });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((end+.6)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        [GDSettings.sharedSettings playFeedback:GDFeedbackFreeze];
        GDSettings.sharedSettings.soundEffectsEnabled=NO;
        NSLog(@"QA audio disabled voices=%lu",(unsigned long)self.voices.count);
        [GDSettings.sharedSettings playFeedback:GDFeedbackWild];
        NSLog(@"QA audio disabled request voices=%lu",(unsigned long)self.voices.count);
        GDSettings.sharedSettings.soundEffectsEnabled=original;
        NSLog(@"QA audio tour end restoredSound=%d",original);
    });
}
#endif
@end
