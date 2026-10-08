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
@property(nonatomic) BOOL musicSuspended, applicationSuspended, sessionInterrupted;
@property(nonatomic) GDMusicMode musicMode;
@property(nonatomic) AVAudioPlayer *musicPlayer, *fadingMusicPlayer;
@property(nonatomic) NSMutableDictionary<NSNumber *,AVAudioPlayer *> *musicPlayers;
@property(nonatomic) NSUInteger musicGeneration;
@end

@implementation GDAudioFeedback
+ (instancetype)sharedPlayer {
    static GDAudioFeedback *player; static dispatch_once_t once;
    dispatch_once(&once, ^{ player=[self new]; }); return player;
}
- (instancetype)init {
    if((self=[super init])) {
        _voices=[NSMutableArray array]; _clips=[NSMutableDictionary dictionary]; _lastPlayed=[NSMutableDictionary dictionary];
        _musicPlayers=[NSMutableDictionary dictionary];
        _applicationSuspended=UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgrounded:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgrounded:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activated:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}
- (void)backgrounded:(NSNotification *)notification { self.applicationSuspended=YES; [self stop]; self.sessionReady=NO; }
- (void)activated:(NSNotification *)notification { self.applicationSuspended=NO; [self refreshMusicPreference]; }
- (void)routeChanged:(NSNotification *)notification {
    if([notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue]==AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        [self stopEffects]; [self pauseMusic];
    }
}
- (void)interrupted:(NSNotification *)notification {
    self.sessionReady=NO;
    self.sessionInterrupted=[notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan;
    if(self.sessionInterrupted) [self stop];
    else if([notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue]&AVAudioSessionInterruptionOptionShouldResume) [self refreshMusicPreference];
    else [self pauseMusic];
}
- (void)stopEffects { for(GDAudioVoice *voice in self.voices) [voice.player stop]; [self.voices removeAllObjects]; [self.lastPlayed removeAllObjects]; }
- (void)stop {
    [self stopEffects]; self.musicGeneration++;
    [self.musicPlayer pause]; [self.fadingMusicPlayer pause]; self.fadingMusicPlayer=nil;
}
- (BOOL)prepareSession {
    if(self.sessionReady) return YES;
    if(self.sessionInterrupted || self.applicationSuspended) return NO;
    NSError *error=nil; AVAudioSession *session=AVAudioSession.sharedInstance;
    if(![session setCategory:AVAudioSessionCategoryAmbient error:&error] || ![session setActive:YES error:&error]) { NSLog(@"Audio session unavailable: %@",error); return NO; }
    self.sessionReady=YES; return YES;
}
- (void)setMusicMode:(GDMusicMode)mode {
    if(mode<GDMusicSilent || mode>GDMusicDanger) return;
    BOOL changed=self.musicMode!=mode;
    _musicMode=mode;
    if(changed) [self refreshMusicPreference];
}
- (void)pauseMusic {
    if(self.musicSuspended) return;
    self.musicSuspended=YES; self.musicGeneration++;
    [self.musicPlayer pause]; [self.fadingMusicPlayer pause]; self.fadingMusicPlayer=nil;
}
- (void)resumeMusic { self.musicSuspended=NO; [self refreshMusicPreference]; }
- (void)refreshMusicPreference {
    if(!GDSettings.sharedSettings.musicEnabled || self.musicMode==GDMusicSilent || self.musicSuspended || self.applicationSuspended || self.sessionInterrupted) {
        self.musicGeneration++; [self.musicPlayer pause]; [self.fadingMusicPlayer pause]; self.fadingMusicPlayer=nil;
        return;
    }
    if(![self prepareSession]) return;
    AVAudioPlayer *next=self.musicPlayers[@(self.musicMode)];
    if(!next) {
        NSString *name=self.musicMode==GDMusicDanger?@"music_danger":@"music_relaxed";
        NSURL *url=[NSBundle.mainBundle URLForResource:name withExtension:@"wav"]; NSError *error=nil;
        next=url?[[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error]:nil;
        if(!next){ NSLog(@"Could not load music %@: %@",name,error?:@"missing bundled clip"); return; }
        next.numberOfLoops=-1; [next prepareToPlay]; self.musicPlayers[@(self.musicMode)]=next;
    }
    if(next==self.musicPlayer && next.playing) return;
    AVAudioPlayer *previous=self.musicPlayer;
    if(self.fadingMusicPlayer && self.fadingMusicPlayer!=next) [self.fadingMusicPlayer stop];
    self.fadingMusicPlayer=nil;
    if(previous && previous!=next && previous.duration>0) {
        // Both arrangements share the score: carry the current bar into the new tempo.
        next.currentTime=fmod(previous.currentTime/previous.duration,1)*next.duration;
    }
    next.volume=0;
    if(![next play]) { NSLog(@"Could not play music mode=%ld",(long)self.musicMode); return; }
    self.musicPlayer=next; NSUInteger generation=++self.musicGeneration;
    [next setVolume:.30 fadeDuration:.45];
    if(previous && previous!=next && previous.playing) {
        self.fadingMusicPlayer=previous; [previous setVolume:0 fadeDuration:.40];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.45*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            if(self.musicGeneration==generation && self.fadingMusicPlayer==previous) { [previous pause]; self.fadingMusicPlayer=nil; }
        });
    }
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-feedback"]) NSLog(@"QA music mode=%ld playing=%d time=%.3f duration=%.3f loops=%ld",(long)self.musicMode,next.playing,next.currentTime,next.duration,(long)next.numberOfLoops);
#endif
}
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity {
    [self playFeedback:feedback intensity:intensity color:-1];
}
- (void)playFeedback:(GDFeedbackType)feedback intensity:(CGFloat)intensity color:(NSInteger)color {
    if(feedback<GDFeedbackTap || feedback>GDFeedbackBlastReady || !GDSettings.sharedSettings.soundEffectsEnabled || self.applicationSuspended || self.sessionInterrupted) return;
    static NSArray<NSString *> *names; static dispatch_once_t once;
    dispatch_once(&once, ^{ names=@[@"tap",@"shot",@"match",@"skill",@"game_over",@"error",@"fall",@"combo",@"freeze",@"blast",@"sweep",@"wild",@"ready",@"win",@"blast_ready"]; });
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    NSNumber *key=@(feedback);
    if(now-self.lastPlayed[key].doubleValue < (feedback==GDFeedbackTap?.045:.06)) return;
    NSInteger priority=(feedback==GDFeedbackTap?0:(feedback==GDFeedbackShot?1:((feedback==GDFeedbackMatch||feedback==GDFeedbackFall)?2:3)));
    if(feedback==GDFeedbackGameOver || feedback==GDFeedbackWin) { [self stopEffects]; priority=4; }
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
    if(![self prepareSession]) return;
    NSString *name=names[feedback];
    self.variation++;
    if(feedback==GDFeedbackMatch && self.variation%2==0) name=@"match_alt";
    if(color>=0 && color<4 && (feedback==GDFeedbackShot || feedback==GDFeedbackMatch)) name=[NSString stringWithFormat:@"%@_%@",feedback==GDFeedbackShot?@"shot":@"match",@[@"blue",@"red",@"yellow",@"white"][color]];
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
- (NSDictionary *)qaAudioState {
    return @{@"mode":@(self.musicMode),@"playing":@(self.musicPlayer.playing),@"fading":@(self.fadingMusicPlayer.playing),@"suspended":@(self.musicSuspended),@"voices":@(self.voices.count)};
}
- (void)startQAPlaybackTour {
    BOOL original=GDSettings.sharedSettings.soundEffectsEnabled, originalMusic=GDSettings.sharedSettings.musicEnabled;
    GDSettings.sharedSettings.soundEffectsEnabled=YES; GDSettings.sharedSettings.musicEnabled=YES;
    NSLog(@"QA audio tour begin");
    for(NSInteger i=0;i<=GDFeedbackBlastReady;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((1+i*.9)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [GDSettings.sharedSettings playFeedback:i intensity:.8]; });
    NSTimeInterval colors=1+(GDFeedbackBlastReady+1)*.9;
    for(NSInteger i=0;i<8;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((colors+i*.55)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [GDSettings.sharedSettings playFeedback:i%2?GDFeedbackMatch:GDFeedbackShot intensity:.8 color:i/2]; });
    NSTimeInterval end=colors+8*.55;
    for(NSInteger i=0;i<16;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((end+i*.025)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [GDSettings.sharedSettings playFeedback:(GDFeedbackType)(GDFeedbackFall+i%6) intensity:1]; });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((end+.6)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        [GDSettings.sharedSettings playFeedback:GDFeedbackFreeze];
        GDSettings.sharedSettings.soundEffectsEnabled=NO;
        NSLog(@"QA audio disabled voices=%lu",(unsigned long)self.voices.count);
        [GDSettings.sharedSettings playFeedback:GDFeedbackWild];
        NSLog(@"QA audio disabled request voices=%lu",(unsigned long)self.voices.count);
        NSAssert(self.voices.count==0 && self.musicPlayer.playing,@"Effects Off must leave music playing");
        NSLog(@"QA audio independent effectsOff=%@",self.qaAudioState);
        GDSettings.sharedSettings.soundEffectsEnabled=YES;
        GDSettings.sharedSettings.musicEnabled=NO;
        [GDSettings.sharedSettings playFeedback:GDFeedbackWild];
        NSAssert(!self.musicPlayer.playing && !self.fadingMusicPlayer.playing && self.voices.count==1,@"Music Off must leave effects available");
        NSLog(@"QA audio independent musicOff=%@",self.qaAudioState);
        GDSettings.sharedSettings.musicEnabled=YES;
        [self setMusicMode:GDMusicDanger];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.7*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            NSAssert(self.musicPlayer.playing && !self.fadingMusicPlayer.playing,@"Danger transition must retire the outgoing loop");
            NSLog(@"QA audio danger=%@",self.qaAudioState);
            [self pauseMusic];
            NSAssert(!self.musicPlayer.playing,@"Pause must stop the music timeline");
            [self resumeMusic];
            NSAssert(self.musicPlayer.playing,@"Resume must restart music");
            [self backgrounded:nil];
            NSAssert(!self.musicPlayer.playing && self.voices.count==0,@"Background must silence all audio");
            [self activated:nil];
            NSAssert(self.musicPlayer.playing,@"Foreground menu music resumes");
            [self interrupted:[NSNotification notificationWithName:AVAudioSessionInterruptionNotification object:nil userInfo:@{AVAudioSessionInterruptionTypeKey:@(AVAudioSessionInterruptionTypeBegan)}]];
            NSAssert(!self.musicPlayer.playing,@"Interruption must pause music");
            [self interrupted:[NSNotification notificationWithName:AVAudioSessionInterruptionNotification object:nil userInfo:@{AVAudioSessionInterruptionTypeKey:@(AVAudioSessionInterruptionTypeEnded),AVAudioSessionInterruptionOptionKey:@(AVAudioSessionInterruptionOptionShouldResume)}]];
            NSAssert(self.musicPlayer.playing,@"Permitted interruption recovery resumes music");
            [self routeChanged:[NSNotification notificationWithName:AVAudioSessionRouteChangeNotification object:nil userInfo:@{AVAudioSessionRouteChangeReasonKey:@(AVAudioSessionRouteChangeReasonOldDeviceUnavailable)}]];
            NSAssert(!self.musicPlayer.playing,@"Unplugged headphones must pause music");
            GDSettings.sharedSettings.musicEnabled=NO; GDSettings.sharedSettings.musicEnabled=YES;
            NSAssert(self.musicPlayer.playing,@"Explicit Music On must resume after a route pause");
            [self setMusicMode:GDMusicSilent];
            NSAssert(!self.musicPlayer.playing,@"Terminal mode must stop music");
            NSLog(@"QA audio lifecycle PASS");
            [self setMusicMode:GDMusicRelaxed];
            GDSettings.sharedSettings.soundEffectsEnabled=original;
            GDSettings.sharedSettings.musicEnabled=originalMusic;
            NSLog(@"QA audio tour end restoredSound=%d restoredMusic=%d",original,originalMusic);
        });
    });
}
#endif
@end
