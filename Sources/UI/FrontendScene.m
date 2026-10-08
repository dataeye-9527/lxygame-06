#import "FrontendScene.h"
#import "GameScene.h"
#import "GummyUI.h"
#import "GDEngine.h"
#import "GDSettings.h"
#import "GDLevelCatalog.h"
#import "GDProgressStore.h"
#import "GDRunRecords.h"

static UIColor *MenuInk(void) { return [UIColor colorWithRed:.35 green:.14 blue:.48 alpha:1]; }
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
- (SKLabelNode *)homeLabel:(NSString *)text size:(CGFloat)size color:(UIColor *)color at:(CGPoint)position parent:(SKNode *)parent {
    SKLabelNode *label=[GummyUI label:text size:size color:color];
    label.position=position; label.zPosition=parent==self?4:2; [parent addChild:label]; return label;
}
- (void)homeButton:(NSString *)title name:(NSString *)name atlas:(NSString *)atlas row:(NSInteger)row icon:(NSString *)icon center:(CGPoint)position size:(CGSize)size fontSize:(CGFloat)fontSize color:(UIColor *)color enabled:(BOOL)enabled {
    SKNode *root=[GummyUI candyButton:title size:size name:name atlas:atlas row:row icon:icon fontSize:fontSize color:color enabled:enabled];
    root.position=position; root.zPosition=5; [self addChild:root];
    CGFloat touchHeight=[atlas isEqualToString:@"home_footer_v4"]?MAX(74,size.height):size.height;
    if(enabled) self.controls[name]=[NSValue valueWithCGRect:CGRectMake(position.x-size.width/2,position.y-touchHeight/2,size.width,touchHeight)];
}
- (void)buildHome {
    self.runSnapshot=[self validSnapshotForKey:@"GummyRunSnapshot"];
    self.levelSnapshot=[self validSnapshotForKey:@"GummyLevelRunSnapshot"];
    SKSpriteNode *title=[GummyUI image:@"home_logo_v4" size:CGSizeMake(506,242)]; title.position=CGPointMake(383,548); title.zPosition=4;
    title.isAccessibilityElement=YES; title.accessibilityLabel=@"Gummy Ricochet"; [self addChild:title];
    SKSpriteNode *hero=[GummyUI image:@"home_hero_v4" size:CGSizeMake(470,470)]; hero.position=CGPointMake(365,248); hero.zPosition=2; [self addChild:hero];
    GDProgressStore *progress=[[GDProgressStore alloc] initWithDefaults:NSUserDefaults.standardUserDefaults];
    UIColor *purple=[UIColor colorWithRed:.35 green:.14 blue:.48 alpha:1];
    SKNode *score=[SKNode node]; score.zPosition=4; [self addChild:score];
    [self homeLabel:@"BEST" size:21 color:[UIColor colorWithRed:.47 green:.32 blue:.55 alpha:1] at:CGPointMake(339,96) parent:score];
    SKLabelNode *best=[self homeLabel:[NSString stringWithFormat:@"%ld",(long)[NSUserDefaults.standardUserDefaults integerForKey:@"GDPrototypeBestScore"]] size:33 color:[UIColor colorWithRed:.76 green:.09 blue:.34 alpha:1] at:CGPointMake(429,96) parent:score];
    SKSpriteNode *bestFace=(SKSpriteNode *)[best childNodeWithName:@"textFace"];
    while(bestFace.size.width-2>100 && best.fontSize>18) best.fontSize-=1;
    for(NSInteger i=0;i<2;i++){
        CGFloat y=i?257:474;
        SKSpriteNode *card=[GummyUI image:@"home_card_v4" size:CGSizeMake(510,i?200:212)]; card.position=CGPointMake(882,y); card.zPosition=3; [self addChild:card];
        CGFloat headerY=i?322:538;
        [self homeLabel:i?@"LEVELS":@"ENDLESS" size:40 color:purple at:CGPointMake(882,headerY) parent:self];
        for(NSInteger side=-1;side<=1;side+=2){
            SKTexture *starTexture=[SKTexture textureWithRect:CGRectMake(883/1254.0,1-264/1254.0,95/1254.0,89/1254.0) inTexture:hero.texture];
            SKNode *star=[SKSpriteNode spriteNodeWithTexture:starTexture size:CGSizeMake(35,33)];
            star.position=CGPointMake(882+side*(i?108:122),headerY); star.zPosition=4; [self addChild:star];
        }
    }
    [self homeLabel:@"Play for your best score" size:19 color:[UIColor colorWithRed:.48 green:.32 blue:.55 alpha:1] at:CGPointMake(882,501) parent:self];
    NSString *detail=[NSString stringWithFormat:@"%ld / 30 unlocked  •  %ld ★",(long)progress.unlockedLevel,(long)progress.totalStars];
    [self homeLabel:detail size:19 color:[UIColor colorWithRed:.48 green:.32 blue:.55 alpha:1] at:CGPointMake(882,284) parent:self];
    [self homeButton:@"New Game" name:@"play" atlas:@"home_buttons_v4" row:0 icon:@"play.fill" center:CGPointMake(774,443) size:CGSizeMake(251,76) fontSize:30 color:UIColor.whiteColor enabled:YES];
    [self homeButton:@"Resume" name:@"resume" atlas:@"home_buttons_v4" row:1 icon:@"pause.fill" center:CGPointMake(1010,443) size:CGSizeMake(210,76) fontSize:30 color:UIColor.whiteColor enabled:self.runSnapshot!=nil];
    [self homeButton:@"Select Level" name:@"levels" atlas:@"home_buttons_v4" row:2 icon:@"square.grid.2x2.fill" center:CGPointMake(self.levelSnapshot?783:882,219) size:CGSizeMake(self.levelSnapshot?253:451,82) fontSize:self.levelSnapshot?26:34 color:[UIColor colorWithRed:.52 green:.15 blue:.17 alpha:1] enabled:YES];
    if(self.levelSnapshot) [self homeButton:[NSString stringWithFormat:@"Resume %ld",(long)[self.levelSnapshot[@"levelID"] integerValue]] name:@"resumeLevel" atlas:@"home_buttons_v4" row:1 icon:@"play.fill" center:CGPointMake(1020,219) size:CGSizeMake(174,82) fontSize:20 color:UIColor.whiteColor enabled:YES];
    [self homeButton:@"Local Scores" name:@"leaderboard" atlas:@"home_footer_v4" row:0 icon:@"trophy.fill" center:CGPointMake(716,109) size:CGSizeMake(181,58) fontSize:19 color:purple enabled:YES];
    [self homeButton:@"Settings" name:@"settings" atlas:@"home_footer_v4" row:1 icon:@"gearshape.fill" center:CGPointMake(890,109) size:CGSizeMake(162,58) fontSize:19 color:purple enabled:YES];
    [self homeButton:@"Help" name:@"help" atlas:@"home_footer_v4" row:2 icon:@"questionmark.circle.fill" center:CGPointMake(1051,109) size:CGSizeMake(151,58) fontSize:19 color:purple enabled:YES];
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
    SKLabelNode *heading=[GummyUI label:title size:37 color:MenuInk()]; heading.position=CGPointMake(600,548); [self addChild:heading];
    CGFloat offset=((SKSpriteNode *)[heading childNodeWithName:@"textFace"]).size.width/2+35;
    for(NSInteger side=-1;side<=1;side+=2){ SKNode *star=[GummyUI star:31]; star.position=CGPointMake(600+side*offset,548); [self addChild:star]; }
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
        SKNode *icon=[GummyUI symbol:@[@"speaker.wave.2.fill",@"hand.tap.fill",@"scope"][i] size:32 color:MenuInk()]; icon.position=CGPointMake(273,y); [self addChild:icon];
        SKLabelNode *label=[GummyUI label:titles[i] size:27 color:MenuInk()]; label.horizontalAlignmentMode=SKLabelHorizontalAlignmentModeLeft; label.position=CGPointMake(315,y); [self addChild:label];
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
        CGFloat x=300+i*200;
        SKNode *tile=[GummyUI surface:CGSizeMake(180,138) color:[UIColor colorWithRed:.99 green:.89 blue:.90 alpha:1] radius:22]; tile.position=CGPointMake(x,219); [self addChild:tile];
        SKNode *piece=[GummyUI piece:i diameter:40]; piece.position=CGPointMake(x,252); [self addChild:piece];
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
