#import "FrontendScene.h"
#import "GameScene.h"
#import "GummyUI.h"
#import "GDEngine.h"
#import "GDSettings.h"
#import "GDLevelCatalog.h"
#import "GDProgressStore.h"
#import "GDRunRecords.h"

static UIColor *MenuInk(void) { return [UIColor colorWithRed:.34 green:.26 blue:.43 alpha:1]; }
static UIColor *MenuCream(void) { return [UIColor colorWithRed:1 green:.93 blue:.87 alpha:1]; }
static UIColor *MenuBlue(void) { return [UIColor colorWithRed:.65 green:.86 blue:1 alpha:1]; }
@interface FrontendScene ()
@property(nonatomic,copy) NSString *page;
@property(nonatomic) SKScene *returnScene;
@property(nonatomic) NSMutableDictionary<NSString *,NSValue *> *controls;
@property(nonatomic) NSDictionary *runSnapshot, *levelSnapshot;
@property(nonatomic) NSInteger chapter, leaderboardPage;
@property(nonatomic) UITouch *activeTouch;
@property(nonatomic,copy) NSString *pressedControl;
@end
@implementation FrontendScene
+ (instancetype)homeScene { FrontendScene *s=[self sceneWithSize:CGSizeMake(1200,680)]; s.page=@"home";
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-scores"] || [NSProcessInfo.processInfo.arguments containsObject:@"-qa-scores-empty"]) s.page=@"leaderboard";
#endif
    s.scaleMode=SKSceneScaleModeAspectFit; return s; }
+ (instancetype)levelsScene { FrontendScene *s=[self homeScene]; s.page=@"levels"; GDProgressStore *progress=[[GDProgressStore alloc] initWithDefaults:NSUserDefaults.standardUserDefaults]; s.chapter=MIN(5,(progress.unlockedLevel-1)/5); return s; }
+ (instancetype)leaderboardScene { FrontendScene *s=[self homeScene]; s.page=@"leaderboard"; return s; }
+ (instancetype)helpScene { FrontendScene *s=[self homeScene]; s.page=@"help"; return s; }
+ (instancetype)settingsSceneReturningTo:(SKScene *)scene { FrontendScene *s=[self homeScene]; s.page=@"settings"; s.returnScene=scene; return s; }
- (void)didMoveToView:(SKView *)view { [GummyUI setOverlayDimmed:NO]; [self rebuild]; }
- (void)text:(NSString *)text size:(CGFloat)size at:(CGPoint)p { SKLabelNode *label=[GummyUI label:text size:size color:MenuInk()]; label.position=p; [self addChild:label]; }
- (void)button:(NSString *)text name:(NSString *)name center:(CGPoint)p size:(CGSize)size color:(UIColor *)color {
    SKNode *node=[GummyUI button:text size:size name:name color:color]; node.position=p; node.zPosition=5; [self addChild:node]; self.controls[name]=[NSValue valueWithCGRect:CGRectMake(p.x-size.width/2,p.y-size.height/2,size.width,size.height)];
}
- (void)rebuild {
    [self removeAllChildren]; self.controls=[NSMutableDictionary dictionary]; [GummyUI addBackgroundTo:self];
    if([self.page isEqualToString:@"home"]) [self buildHome];
    else if([self.page isEqualToString:@"settings"]) [self buildSettings];
    else if([self.page isEqualToString:@"levels"]) [self buildLevels];
    else if([self.page isEqualToString:@"leaderboard"]) [self buildLeaderboard];
    else [self buildHelp];
}
- (NSDictionary *)validSnapshotForKey:(NSString *)key {
    id snapshot=[NSUserDefaults.standardUserDefaults objectForKey:key];
    GDEngine *restored=[snapshot isKindOfClass:NSDictionary.class]?[[GDEngine alloc] initWithSnapshot:snapshot]:nil;
    return restored && restored.phase!=GDPhaseGameOver && restored.phase!=GDPhaseWon?snapshot:nil;
}
- (void)buildHome {
    self.runSnapshot=[self validSnapshotForKey:@"GummyRunSnapshot"];
    self.levelSnapshot=[self validSnapshotForKey:@"GummyLevelRunSnapshot"];
    SKNode *titleCard=[GummyUI surface:CGSizeMake(465,100) color:MenuCream() radius:40]; titleCard.position=CGPointMake(335,577); [self addChild:titleCard];
    [self text:@"GUMMY DROP" size:48 at:CGPointMake(335,578)];
    SKSpriteNode *hero=[GummyUI image:@"menu_hero" size:CGSizeMake(480,360)]; hero.position=CGPointMake(335,339); if(hero) [self addChild:hero];
    [hero runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction moveByX:0 y:6 duration:2],[SKAction moveByX:0 y:-6 duration:2]]]]];
    GDProgressStore *progress=[[GDProgressStore alloc] initWithDefaults:NSUserDefaults.standardUserDefaults];
    [self text:[NSString stringWithFormat:@"BEST  %ld",(long)[NSUserDefaults.standardUserDefaults integerForKey:@"GDPrototypeBestScore"]] size:23 at:CGPointMake(335,128)];
    for(NSInteger mode=0;mode<2;mode++){
        CGFloat y=mode?280:488;
        SKNode *card=[GummyUI surface:CGSizeMake(445,183) color:MenuCream() radius:30]; card.position=CGPointMake(865,y); [self addChild:card];
        [self text:mode?@"LEVELS":@"ENDLESS" size:25 at:CGPointMake(865,y+56)];
        NSString *detail=mode?[NSString stringWithFormat:@"%ld / 30 unlocked   ·   %ld ★",(long)progress.unlockedLevel,(long)progress.totalStars]:@"Play for your best score";
        [self text:detail size:17 at:CGPointMake(865,y+21)];
        BOOL saved=mode?self.levelSnapshot!=nil:self.runSnapshot!=nil;
        [self button:mode?@"Select Level":(saved?@"New Game":@"Play") name:mode?@"levels":@"play" center:CGPointMake(saved?777:865,y-37) size:CGSizeMake(saved?208:350,57) color:mode?[UIColor colorWithRed:1 green:.85 blue:.58 alpha:1]:MenuBlue()];
        if(saved){
            NSString *resume=mode?[NSString stringWithFormat:@"Resume %ld",(long)[self.levelSnapshot[@"levelID"] integerValue]]:@"Resume";
            [self button:resume name:mode?@"resumeLevel":@"resume" center:CGPointMake(975,y-37) size:CGSizeMake(166,57) color:[UIColor colorWithRed:.87 green:.81 blue:.97 alpha:1]];
        }
    }
    [self button:@"Local Scores" name:@"leaderboard" center:CGPointMake(741,121) size:CGSizeMake(194,54) color:[UIColor colorWithRed:.87 green:.81 blue:.97 alpha:1]];
    [self button:@"Settings" name:@"settings" center:CGPointMake(915,121) size:CGSizeMake(138,54) color:[UIColor colorWithRed:.99 green:.80 blue:.85 alpha:1]];
    [self button:@"Help" name:@"help" center:CGPointMake(1062,121) size:CGSizeMake(124,54) color:MenuCream()];
}
- (NSString *)objectiveText:(GDLevel *)level {
    switch(level.objective){
        case GDObjectiveClear: return [NSString stringWithFormat:@"%lu wave%@",(unsigned long)level.layouts.count,level.layouts.count==1?@"":@"s"];
        case GDObjectiveCollect: return [NSString stringWithFormat:@"%ld %@",(long)level.target,@[@"blue",@"red",@"yellow",@"white"][level.objectiveColor]];
        case GDObjectiveFall: return [NSString stringWithFormat:@"%ld gummies",(long)level.target];
        case GDObjectiveSurvive: return [NSString stringWithFormat:@"%ld seconds",(long)level.target];
    }
}
- (void)buildLevels {
    [self pageFrame:@"LEVELS"];
    GDProgressStore *progress=[[GDProgressStore alloc] initWithDefaults:NSUserDefaults.standardUserDefaults];
    for(NSInteger c=0;c<6;c++) [self button:[NSString stringWithFormat:@"%ld",(long)c+1] name:[NSString stringWithFormat:@"chapter%ld",(long)c] center:CGPointMake(350+c*100,488) size:CGSizeMake(78,44) color:c==self.chapter?MenuBlue():[UIColor colorWithRed:.91 green:.85 blue:.96 alpha:1]];
    [self text:[NSString stringWithFormat:@"CHAPTER %ld   ·   %ld / 90 ★",(long)self.chapter+1,(long)progress.totalStars] size:16 at:CGPointMake(600,445)];
    for(NSInteger i=0;i<5;i++){
        NSInteger levelID=self.chapter*5+i+1; GDLevel *level=[GDLevelCatalog levelForID:levelID]; if(!level) continue;
        BOOL unlocked=[progress isLevelUnlocked:levelID]; CGFloat x=252+i*174;
        SKNode *tile=[GummyUI surface:CGSizeMake(160,248) color:unlocked?[UIColor colorWithRed:.97 green:.85 blue:.84 alpha:1]:[UIColor colorWithRed:.85 green:.81 blue:.89 alpha:1] radius:25]; tile.position=CGPointMake(x,286); [self addChild:tile];
        if(levelID==progress.unlockedLevel){ SKShapeNode *rim=[GummyUI panel:CGSizeMake(155,243) fill:UIColor.clearColor stroke:MenuBlue() radius:23]; rim.position=tile.position; rim.lineWidth=4; [self addChild:rim]; }
        [self text:[NSString stringWithFormat:@"%02ld",(long)levelID] size:34 at:CGPointMake(x,369)];
        SKNode *piece=[GummyUI piece:level.objective==GDObjectiveCollect?level.objectiveColor:(levelID-1)%4 diameter:48]; piece.position=CGPointMake(x,315); [self addChild:piece];
        [self text:@[@"CLEAR",@"COLLECT",@"DROP",@"SURVIVE"][level.objective] size:12 at:CGPointMake(x,277)];
        [self text:[self objectiveText:level] size:14 at:CGPointMake(x,255)];
        NSInteger stars=[progress bestStarsForLevel:levelID];
        [self text:stars?[@[@"",@"★ ☆ ☆",@"★ ★ ☆",@"★ ★ ★"] objectAtIndex:stars]:@"☆ ☆ ☆" size:20 at:CGPointMake(x,231)];
        NSString *efficiency=level.objective==GDObjectiveSurvive?[NSString stringWithFormat:@"≤%ld shots / ≥%ld pts",(long)level.parShots,(long)level.parScore]:[NSString stringWithFormat:@"≤%ld shots / ≤%.0fs",(long)level.parShots,level.parTime];
        SKLabelNode *par=[GummyUI label:efficiency size:11.5 color:MenuInk()]; par.position=CGPointMake(x,212); while(par.frame.size.width>146 && par.fontSize>10) par.fontSize-=.5; [self addChild:par];
        if(unlocked) [self button:@"Play" name:[NSString stringWithFormat:@"level%ld",(long)levelID] center:CGPointMake(x,181) size:CGSizeMake(124,42) color:MenuBlue()];
        else [self text:@"LOCKED" size:16 at:CGPointMake(x,182)];
    }
    [self text:@"3★: complete + shot efficiency + time. Survival rewards score." size:17 at:CGPointMake(600,106)];
}
- (void)buildLeaderboard {
    [self pageFrame:@"LOCAL SCORES"];
    NSArray *records=[[[GDRunRecords alloc] initWithDefaults:NSUserDefaults.standardUserDefaults] records];
#if DEBUG
    NSArray *args=NSProcessInfo.processInfo.arguments;
    if([args containsObject:@"-qa-scores"] || [args containsObject:@"-qa-scores-empty"]){
        NSMutableArray *fixtures=[NSMutableArray array];
        if([args containsObject:@"-qa-scores"]) for(NSInteger i=0;i<17;i++) [fixtures addObject:@{@"score":@((17-i)*495),@"elapsed":@(40+i*31),@"date":@(1790726400+i*3600)}];
        records=fixtures;
        [self text:@"QA FIXTURE" size:12 at:CGPointMake(930,549)];
    }
#endif
    if(!records.count){ [self text:@"No scores yet" size:28 at:CGPointMake(600,351)]; [self text:@"Finish an Endless run to set your first score." size:20 at:CGPointMake(600,302)]; return; }
    [self text:@"RANK" size:14 at:CGPointMake(245,495)]; [self text:@"SCORE" size:14 at:CGPointMake(422,495)]; [self text:@"TIME" size:14 at:CGPointMake(632,495)]; [self text:@"DATE" size:14 at:CGPointMake(876,495)];
    NSDateFormatter *formatter=[NSDateFormatter new]; formatter.dateFormat=@"MMM d, HH:mm"; formatter.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    NSInteger start=self.leaderboardPage*7;
    for(NSInteger i=start;i<MIN(start+7,(NSInteger)records.count);i++){
        NSDictionary *record=records[i]; CGFloat y=453-(i-start)*44;
        SKNode *row=[GummyUI surface:CGSizeMake(772,37) color:i==0?[UIColor colorWithRed:1 green:.86 blue:.57 alpha:1]:[UIColor colorWithRed:.97 green:.87 blue:.86 alpha:1] radius:14]; row.position=CGPointMake(600,y); [self addChild:row];
        [self text:[NSString stringWithFormat:@"%ld",(long)i+1] size:18 at:CGPointMake(245,y)];
        [self text:[record[@"score"] stringValue] size:21 at:CGPointMake(422,y)];
        NSInteger seconds=[record[@"elapsed"] integerValue]; [self text:[NSString stringWithFormat:@"%ld:%02ld",(long)seconds/60,(long)seconds%60] size:18 at:CGPointMake(632,y)];
        [self text:[formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[record[@"date"] doubleValue]]] size:16 at:CGPointMake(876,y)];
    }
    NSInteger pages=(records.count+6)/7; [self text:[NSString stringWithFormat:@"%ld / %ld",(long)self.leaderboardPage+1,(long)pages] size:17 at:CGPointMake(600,112)];
    if(self.leaderboardPage>0) [self button:@"Previous" name:@"scoresPrev" center:CGPointMake(351,112) size:CGSizeMake(150,43) color:MenuBlue()];
    if(self.leaderboardPage+1<pages) [self button:@"Next" name:@"scoresNext" center:CGPointMake(849,112) size:CGSizeMake(150,43) color:MenuBlue()];
}
- (void)pageFrame:(NSString *)title {
    SKNode *card=[GummyUI surface:CGSizeMake(904,546) color:MenuCream() radius:36]; card.position=CGPointMake(600,338); [self addChild:card];
    [self text:title size:37 at:CGPointMake(600,548)];
    [self button:@"Back" name:@"back" center:CGPointMake(228,615) size:CGSizeMake(150,52) color:MenuCream()];
}
- (void)buildSettings {
    [self pageFrame:@"SETTINGS"];
    NSArray *titles=@[@"Sound Effects",@"Haptics",@"Aim Guide"];
    GDSettings *settings=GDSettings.sharedSettings;
    NSArray *values=@[@(settings.soundEffectsEnabled),@(settings.hapticsEnabled),@(settings.aimGuideEnabled)];
    NSArray *keys=@[@"sound",@"haptics",@"guide"];
    for(NSInteger i=0;i<3;i++){
        CGFloat y=438-i*112;
        SKNode *row=[GummyUI surface:CGSizeMake(760,86) color:[UIColor colorWithRed:.98 green:.88 blue:.86 alpha:1] radius:24]; row.position=CGPointMake(600,y); [self addChild:row];
        SKLabelNode *label=[GummyUI label:titles[i] size:27 color:MenuInk()]; label.horizontalAlignmentMode=SKLabelHorizontalAlignmentModeLeft; label.position=CGPointMake(262,y); [self addChild:label];
        [self button:[values[i] boolValue]?@"On":@"Off" name:keys[i] center:CGPointMake(860,y) size:CGSizeMake(140,56) color:[values[i] boolValue]?MenuBlue():[UIColor colorWithRed:.81 green:.77 blue:.86 alpha:1]];
    }
}
- (void)buildHelp {
    [self pageFrame:@"HOW TO PLAY"];
    [self text:@"Drag to aim. Release to shoot." size:23 at:CGPointMake(600,471)];
    [self text:@"Match 3 of one color. Unsupported gummies fall." size:20 at:CGPointMake(600,432)];
    [self text:@"Tap a cannon to switch. Bounce off a wall once." size:20 at:CGPointMake(600,393)];
    [self text:@"Hold swaps your gummy once per normal shot." size:20 at:CGPointMake(600,354)];
    [self text:@"Keep gummies above the danger line." size:20 at:CGPointMake(600,315)];
    NSArray *labels=@[@"FREEZE",@"BLAST",@"SWEEP",@"WILD"];
    NSArray *first=@[@"Stops rows",@"Aim, then fire",@"Clears bottom",@"Next 3 shots"];
    NSArray *second=@[@"for 6 seconds",@"at first hit",@"2 rows",@"auto-match a color"];
    for(NSInteger i=0;i<4;i++){
        CGFloat x=300+i*200; SKNode *piece=[GummyUI piece:i diameter:40]; piece.position=CGPointMake(x,252); [self addChild:piece];
        if(i==3){ [piece removeFromParent]; SKNode *star=[GummyUI image:@"wild_icon" size:CGSizeMake(45,45)]; star.position=CGPointMake(x,252); if(star) [self addChild:star]; }
        [self text:labels[i] size:17 at:CGPointMake(x,214)]; [self text:first[i] size:15 at:CGPointMake(x,184)]; [self text:second[i] size:15 at:CGPointMake(x,160)];
    }
    [self text:@"Fill each color meter, then tap its skill." size:18 at:CGPointMake(600,109)];
}
- (NSString *)controlAt:(CGPoint)p { for(NSString *key in self.controls) if(CGRectContainsPoint(self.controls[key].CGRectValue,p)) return key; return nil; }
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(self.activeTouch) return; self.activeTouch=touches.anyObject; self.pressedControl=[self controlAt:[self.activeTouch locationInNode:self]];
    if(self.pressedControl){ SKNode *node=[self childNodeWithName:self.pressedControl]; node.xScale=node.yScale=.97; }
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self resetTouch]; }
- (void)resetTouch { if(self.pressedControl){ SKNode *node=[self childNodeWithName:self.pressedControl]; node.xScale=node.yScale=1; } self.activeTouch=nil; self.pressedControl=nil; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(!self.activeTouch || ![touches containsObject:self.activeTouch]) return;
    NSString *control=[self controlAt:[self.activeTouch locationInNode:self]]; BOOL same=control && [control isEqualToString:self.pressedControl]; [self resetTouch]; if(same) [self activate:control];
}
- (void)activate:(NSString *)control {
    GDSettings *settings=GDSettings.sharedSettings; [settings playFeedback:GDFeedbackTap];
    if([control isEqualToString:@"play"] || [control isEqualToString:@"resume"] || [control isEqualToString:@"resumeLevel"]){
        NSDictionary *snapshot=[control isEqualToString:@"resume"]?self.runSnapshot:([control isEqualToString:@"resumeLevel"]?self.levelSnapshot:nil);
        if(!snapshot) [NSUserDefaults.standardUserDefaults removeObjectForKey:@"GummyRunSnapshot"];
        GameScene *game=[[GameScene alloc] initWithSize:self.size runSnapshot:snapshot]; game.scaleMode=SKSceneScaleModeAspectFit; [self.view presentScene:game];
    } else if([control isEqualToString:@"levels"]) [self.view presentScene:[FrontendScene levelsScene]];
    else if([control isEqualToString:@"leaderboard"]) [self.view presentScene:[FrontendScene leaderboardScene]];
    else if([control hasPrefix:@"chapter"]){ self.chapter=[[control substringFromIndex:7] integerValue]; [self rebuild]; }
    else if([control hasPrefix:@"level"]){ NSInteger levelID=[[control substringFromIndex:5] integerValue]; if([[[GDProgressStore alloc] initWithDefaults:NSUserDefaults.standardUserDefaults] isLevelUnlocked:levelID]){ GameScene *game=[[GameScene alloc] initWithSize:self.size levelID:levelID]; game.scaleMode=SKSceneScaleModeAspectFit; [NSUserDefaults.standardUserDefaults removeObjectForKey:@"GummyLevelRunSnapshot"]; [self.view presentScene:game]; } }
    else if([control isEqualToString:@"scoresPrev"] || [control isEqualToString:@"scoresNext"]){ self.leaderboardPage+=[control isEqualToString:@"scoresNext"]?1:-1; [self rebuild]; }
    else if([control isEqualToString:@"settings"]) [self.view presentScene:[FrontendScene settingsSceneReturningTo:self]];
    else if([control isEqualToString:@"help"]) [self.view presentScene:[FrontendScene helpScene]];
    else if([control isEqualToString:@"back"]){ SKScene *destination=self.returnScene?:[FrontendScene homeScene]; self.returnScene=nil; [self.view presentScene:destination]; }
    else {
        if([control isEqualToString:@"sound"]) settings.soundEffectsEnabled=!settings.soundEffectsEnabled;
        if([control isEqualToString:@"haptics"]) settings.hapticsEnabled=!settings.hapticsEnabled;
        if([control isEqualToString:@"guide"]) settings.aimGuideEnabled=!settings.aimGuideEnabled;
        [self rebuild];
    }
}
@end
