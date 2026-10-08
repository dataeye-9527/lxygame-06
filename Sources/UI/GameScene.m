#import "GameScene.h"
#import "GummyUI.h"
#import "GDEngine.h"
#import "FrontendScene.h"
#import "GDSettings.h"
#import "GDAudioFeedback.h"
#import "GDLevelCatalog.h"
#import "GDRunRecords.h"
#import <UIKit/UIKit.h>

static UIColor *Ink(void) { return [UIColor colorWithRed:.35 green:.14 blue:.48 alpha:1]; }
static UIColor *Cream(void) { return [UIColor colorWithRed:1 green:.92 blue:.85 alpha:1]; }
static CGPoint ScenePoint(CGPoint p) { return CGPointMake(174+p.x,603-p.y); }
static CGPoint BoardPoint(CGPoint p) { return CGPointMake(p.x-174,603-p.y); }

@interface GameScene ()
@property(nonatomic) GDEngine *engine;
@property(nonatomic) NSDictionary *initialRunSnapshot;
@property(nonatomic) NSInteger initialLevelID, combo;
#if DEBUG
@property(nonatomic) BOOL clockValidation, qaPresentationFixture;
#endif
@property(nonatomic) NSTimeInterval flightRemaining, resolutionRemaining;
@property(nonatomic) NSArray<NSNumber *> *displayedEnergy;
@property(nonatomic) SKLabelNode *modeLabel, *objectiveLabel;
@property(nonatomic) NSMutableDictionary<NSString *,NSValue *> *overlayControls;
@property(nonatomic) SKNode *playfield, *boardPieces, *effects, *aimLayer, *hud, *overlay;
@property(nonatomic) NSMutableDictionary<NSString *,SKNode *> *pieceNodes;
@property(nonatomic) NSMutableArray<SKNode *> *skillCards, *launcherNodes;
@property(nonatomic) NSMutableArray<SKShapeNode *> *energyFills;
@property(nonatomic) NSMutableArray<SKLabelNode *> *energyLabels;
@property(nonatomic) SKLabelNode *scoreLabel, *timerLabel, *timerTitle, *wildLabel, *holdLabel, *statusLabel;
@property(nonatomic) SKNode *nextPiece, *heldPiece, *currentPiece;
@property(nonatomic) GDShot *preview;
@property(nonatomic) UITouch *aimTouch;
@property(nonatomic) CGPoint aimTouchStart;
@property(nonatomic) BOOL aiming, yellowArmed, renderedGameOver;
@property(nonatomic) BOOL musicDanger;
@property(nonatomic) CGPoint blastImpactPoint;
@property(nonatomic) NSTimeInterval lastTime;
@property(nonatomic) NSInteger renderedRevision, displayedNext, displayedHeld, displayedCurrent, generation;
@end

@implementation GameScene
- (instancetype)initWithSize:(CGSize)size levelID:(NSInteger)levelID { if((self=[super initWithSize:size])) self.initialLevelID=levelID; return self; }
- (instancetype)initWithSize:(CGSize)size runSnapshot:(NSDictionary *)snapshot {
    if((self=[super initWithSize:size])) self.initialRunSnapshot=snapshot; return self;
}
- (void)didMoveToView:(SKView *)view {
    [GummyUI setOverlayDimmed:self.overlay!=nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundPause:) name:UIApplicationWillResignActiveNotification object:nil];
    if(self.engine){ self.lastTime=0; [self refreshHUD]; [self refreshMusic]; if(self.engine.phase!=GDPhasePaused) [GDAudioFeedback.sharedPlayer resumeMusic]; return; }
    self.anchorPoint=CGPointZero;
    self.pieceNodes=[NSMutableDictionary dictionary]; self.skillCards=[NSMutableArray array]; self.launcherNodes=[NSMutableArray array]; self.energyFills=[NSMutableArray array]; self.energyLabels=[NSMutableArray array];
    self.displayedNext=self.displayedHeld=self.displayedCurrent=-99; self.renderedRevision=-1;
    self.flightRemaining=self.resolutionRemaining=-1; self.displayedEnergy=@[@0,@0,@0,@0];
#if DEBUG
    NSArray *args=NSProcessInfo.processInfo.arguments;
#endif
    NSDictionary *saved=self.initialRunSnapshot; self.initialRunSnapshot=nil;
    NSUInteger seed=[self newRunSeed];
    self.engine=saved ? [[GDEngine alloc] initWithSnapshot:saved] : (self.initialLevelID>0?[[GDEngine alloc] initWithLevelID:self.initialLevelID seed:[GDLevelCatalog levelForID:self.initialLevelID].seed]:[[GDEngine alloc] initWithSeed:seed]);
    if(!self.engine) self.engine=[[GDEngine alloc] initWithSeed:seed];
#if DEBUG
    NSUInteger resultIndex=[args indexOfObject:@"-qa-result"];
    NSString *resultVariant=resultIndex!=NSNotFound && resultIndex+1<args.count?args[resultIndex+1]:nil;
    if([args containsObject:@"-qa-last-level"]) resultVariant=@"last-level-win";
    if(resultIndex!=NSNotFound || resultVariant){
        NSAssert(([@[@"endless-loss",@"level-loss",@"level-win",@"last-level-win"] containsObject:resultVariant]),@"Unknown QA result variant");
        BOOL resultWon=[resultVariant hasSuffix:@"-win"];
        NSInteger levelID=[resultVariant isEqualToString:@"endless-loss"]?0:([resultVariant isEqualToString:@"last-level-win"]?GDLevelCatalog.levels.lastObject.levelID:1);
        GDLevel *fixtureLevel=[GDLevelCatalog levelForID:levelID];
        GDEngine *fixtureEngine=levelID?[[GDEngine alloc] initWithLevelID:levelID seed:fixtureLevel.seed]:[[GDEngine alloc] initWithSeed:20260930];
        NSMutableDictionary *fixture=[fixtureEngine.snapshot mutableCopy];
        fixture[@"won"]=@(resultWon); fixture[@"gameOver"]=@(!resultWon); fixture[@"stars"]=@(resultWon?3:0); fixture[@"completionRecorded"]=@YES;
        fixture[@"score"]=@(levelID?3200:123456);
        if(!levelID){
            NSDictionary *record=[[[GDRunRecords alloc] initWithDefaults:NSUserDefaults.standardUserDefaults] records].lastObject;
            if(record){ fixture[@"runID"]=record[@"runID"]; fixture[@"score"]=record[@"score"]; }
        }
        if(resultWon){ fixture[@"clearedWaves"]=@(fixtureEngine.objectiveTarget); fixture[@"collected"]=@(fixtureEngine.objectiveTarget); fixture[@"fallenTotal"]=@(fixtureEngine.objectiveTarget); fixture[@"elapsed"]=@(MAX(fixtureEngine.objectiveTarget,1)); }
        self.engine=[[GDEngine alloc] initWithSnapshot:fixture]; self.qaPresentationFixture=YES;
        NSAssert(self.engine,@"QA result snapshot must be valid");
    }
    if(!saved && ([args containsObject:@"-qa-ready"] || [args containsObject:@"-qa-freeze-art"] || [args containsObject:@"-qa-blast-art"])) [self.engine setFixtureEnergy:@[@20,@20,@20,@20]];
    if(!saved && [args containsObject:@"-qa-failure"]){
        NSMutableArray *cells=[self.engine.cells mutableCopy];
        for(NSInteger row=6;row<12;row++) [cells addObject:[GDCell row:row column:8 color:GDColorRed]];
        [self.engine loadFixture:cells phase:0 current:GDColorBlue next:GDColorYellow];
    }
#endif
    self.displayedEnergy=[self.engine.energy copy];
    [self buildLayout]; [self syncBoard]; [self refreshHUD];
    if(self.engine.phase==GDPhasePaused) [self.engine resume];
    [self refreshMusic];
    [GDAudioFeedback.sharedPlayer resumeMusic];
#if DEBUG
    if([args containsObject:@"-qa-clock"]) [self validatePresentationClock];
    if([args containsObject:@"-qa-music"]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{ [self validateMusicTransitions]; });
    if([args containsObject:@"-qa-freeze-art"] || [args containsObject:@"-qa-blast-art"]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{ [self captureSkillArt]; });
    if(saved && [args containsObject:@"-qa-feedback"]){ NSData *data=[NSJSONSerialization dataWithJSONObject:self.engine.snapshot options:0 error:nil]; NSLog(@"QA restored snapshot=%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]); }
#endif
}
- (void)willMoveFromView:(SKView *)view { [GummyUI setOverlayDimmed:NO]; [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)buildLayout {
    [GummyUI addBackgroundTo:self];
    SKNode *boardFrame=[GummyUI surface:CGSizeMake(856,582) color:[UIColor colorWithRed:.73 green:.62 blue:.82 alpha:1] radius:25]; boardFrame.position=CGPointMake(588,326); [self addChild:boardFrame];
    SKShapeNode *inner=[GummyUI panel:CGSizeMake(828,555) fill:[UIColor colorWithRed:.30 green:.22 blue:.47 alpha:1] stroke:[UIColor colorWithRed:.76 green:.52 blue:.84 alpha:1] radius:15]; inner.position=CGPointMake(588,324); inner.lineWidth=2; [self addChild:inner];
    SKCropNode *clip=[SKCropNode node]; clip.position=inner.position; clip.maskNode=[GummyUI panel:CGSizeMake(824,551) fill:UIColor.whiteColor stroke:UIColor.clearColor radius:13];
    SKSpriteNode *gradient=[GummyUI gradient:CGSizeMake(824,551) top:[UIColor colorWithRed:.33 green:.26 blue:.51 alpha:1] bottom:[UIColor colorWithRed:.47 green:.34 blue:.65 alpha:1]]; [clip addChild:gradient]; [self addChild:clip];
    SKShapeNode *floor=[GummyUI panel:CGSizeMake(822,61) fill:[UIColor colorWithRed:.65 green:.53 blue:.76 alpha:.24] stroke:UIColor.clearColor radius:11]; floor.position=CGPointMake(588,78); [self addChild:floor];
    self.playfield=[SKNode node]; self.playfield.zPosition=5; [self addChild:self.playfield];
    self.boardPieces=[SKNode node]; [self.playfield addChild:self.boardPieces];
    self.effects=[SKNode node]; self.effects.zPosition=30; [self.playfield addChild:self.effects];
    self.aimLayer=[SKNode node]; self.aimLayer.zPosition=20; [self.playfield addChild:self.aimLayer];
    for(CGFloat x=183;x<995;x+=25){ SKShapeNode *dash=[GummyUI panel:CGSizeMake(12,3) fill:[UIColor colorWithRed:1 green:.44 blue:.50 alpha:.9] stroke:UIColor.clearColor radius:1.5]; dash.position=CGPointMake(x,171); dash.zPosition=4; [self addChild:dash]; }
    self.hud=[SKNode node]; self.hud.zPosition=40; [self addChild:self.hud];
    SKNode *score=[GummyUI surface:CGSizeMake(222,44) color:Cream() radius:22]; score.position=CGPointMake(294,645); [self.hud addChild:score];
    SKLabelNode *scoreTitle=[GummyUI label:@"SCORE" size:17 color:Ink()]; scoreTitle.position=CGPointMake(230,645); [self.hud addChild:scoreTitle];
    self.scoreLabel=[GummyUI label:@"0" size:29 color:Ink()]; self.scoreLabel.position=CGPointMake(325,645); [self.hud addChild:self.scoreLabel];
    SKNode *timer=[GummyUI surface:CGSizeMake(146,54) color:[UIColor colorWithRed:1 green:.68 blue:.82 alpha:1] radius:25]; timer.position=CGPointMake(604,645); [self.hud addChild:timer];
    self.timerTitle=[GummyUI label:@"NEW ROW" size:13 color:Ink()]; self.timerTitle.position=CGPointMake(604,658); [self.hud addChild:self.timerTitle];
    self.timerLabel=[GummyUI label:@"00:12" size:25 color:Ink()]; self.timerLabel.position=CGPointMake(604,636); [self.hud addChild:self.timerLabel];
    SKNode *modeCard=[GummyUI surface:CGSizeMake(282,54) color:Cream() radius:25]; modeCard.position=CGPointMake(871,645); [self.hud addChild:modeCard];
    self.modeLabel=[GummyUI label:@"ENDLESS" size:18 color:Ink()]; self.modeLabel.position=CGPointMake(871,658); [self.hud addChild:self.modeLabel];
    self.objectiveLabel=[GummyUI label:@"" size:13 color:Ink()]; self.objectiveLabel.position=CGPointMake(871,635); [self.hud addChild:self.objectiveLabel];
    SKNode *pause=[GummyUI button:@"Ⅱ" size:CGSizeMake(55,52) name:@"pause" color:Cream()]; pause.position=CGPointMake(1133,643); [self.hud addChild:pause];
    SKNode *left=[GummyUI surface:CGSizeMake(144,605) color:[UIColor colorWithRed:1 green:.86 blue:.82 alpha:1] radius:25]; left.position=CGPointMake(82,329); [self.hud addChild:left];
    NSArray *names=@[@"FREEZE",@"BLAST",@"SWEEP",@"WILD"];
    for(NSInteger i=0;i<4;i++){
        CGFloat y=552-i*146;
        SKNode *card=[SKNode node]; card.name=[NSString stringWithFormat:@"skill%ld",(long)i]; card.position=CGPointMake(82,y); [self.hud addChild:card]; [self.skillCards addObject:card];
        SKNode *body=[GummyUI surface:CGSizeMake(130,138) color:Cream() radius:20]; [card addChild:body];
        SKNode *piece;
        if(i==3){ SKShapeNode *disc=[SKShapeNode shapeNodeWithCircleOfRadius:33]; disc.fillColor=[UIColor colorWithRed:.86 green:.81 blue:.87 alpha:1]; disc.strokeColor=UIColor.whiteColor; disc.lineWidth=2; disc.position=CGPointMake(0,25); [card addChild:disc]; piece=[GummyUI image:@"wild_icon" size:CGSizeMake(55,55)]; }
        else piece=[GummyUI piece:i diameter:64];
        piece.position=CGPointMake(0,25); if(piece) [card addChild:piece];
        SKLabelNode *title=[GummyUI label:names[i] size:16 color:Ink()]; title.position=CGPointMake(0,-16); [card addChild:title];
        SKShapeNode *track=[GummyUI panel:CGSizeMake(108,13) fill:[UIColor colorWithRed:.55 green:.44 blue:.63 alpha:1] stroke:[UIColor colorWithWhite:1 alpha:.7] radius:6]; track.position=CGPointMake(0,-36); [card addChild:track];
        SKShapeNode *fill=[SKShapeNode node]; fill.fillColor=[GummyUI color:i]; fill.strokeColor=UIColor.clearColor; fill.position=CGPointMake(-53,-36); [card addChild:fill]; [self.energyFills addObject:fill];
        SKLabelNode *energy=[GummyUI label:@"0/20" size:15 color:Ink()]; energy.position=CGPointMake(0,-55); [card addChild:energy]; [self.energyLabels addObject:energy];
    }
    SKNode *right=[GummyUI surface:CGSizeMake(145,353) color:[UIColor colorWithRed:1 green:.88 blue:.82 alpha:1] radius:27]; right.position=CGPointMake(1110,411); [self.hud addChild:right];
    SKNode *rightInner=[GummyUI surface:CGSizeMake(130,337) color:Cream() radius:22]; rightInner.position=right.position; [self.hud addChild:rightInner];
    SKLabelNode *next=[GummyUI label:@"NEXT" size:21 color:Ink()]; next.position=CGPointMake(1110,550); [self.hud addChild:next];
    self.holdLabel=[GummyUI label:@"HOLD" size:21 color:Ink()]; self.holdLabel.position=CGPointMake(1110,392); [self.hud addChild:self.holdLabel];
    for(NSInteger i=0;i<2;i++){ SKNode *slot=[GummyUI surface:CGSizeMake(109,108) color:[UIColor colorWithRed:.81 green:.70 blue:.86 alpha:1] radius:21]; slot.position=CGPointMake(1110,i?317:477); slot.name=i?@"hold":@"next"; [self.hud addChild:slot]; }
    self.nextPiece=[SKNode node]; self.nextPiece.position=CGPointMake(1110,477); [self.hud addChild:self.nextPiece];
    self.heldPiece=[SKNode node]; self.heldPiece.position=CGPointMake(1110,317); self.heldPiece.name=@"hold"; [self.hud addChild:self.heldPiece];
    for(NSInteger i=0;i<3;i++){
        SKNode *launcher=[SKNode node]; launcher.position=ScenePoint([self.engine launcherPoint:i]); launcher.name=[NSString stringWithFormat:@"launcher%ld",(long)i]; [self.playfield addChild:launcher]; [self.launcherNodes addObject:launcher];
        SKShapeNode *glow=[SKShapeNode shapeNodeWithEllipseOfSize:CGSizeMake(139,37)]; glow.fillColor=[UIColor colorWithRed:.25 green:.75 blue:1 alpha:.25]; glow.strokeColor=[UIColor colorWithRed:.61 green:.89 blue:1 alpha:1]; glow.lineWidth=3; glow.position=CGPointMake(0,-25); glow.name=@"activeGlow"; [launcher addChild:glow];
        NSString *path=[[NSBundle mainBundle] pathForResource:@"cannon" ofType:@"png"];
        if(path){ SKSpriteNode *cannon=[SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImage:[UIImage imageWithContentsOfFile:path]] size:CGSizeMake(125,112)]; cannon.position=CGPointMake(0,-11); [launcher addChild:cannon]; }
        else {
            SKShapeNode *base=[GummyUI panel:CGSizeMake(125,25) fill:[UIColor colorWithRed:.90 green:.55 blue:.71 alpha:1] stroke:[UIColor colorWithWhite:1 alpha:.7] radius:12]; base.position=CGPointMake(0,-27); [launcher addChild:base];
            SKShapeNode *body=[SKShapeNode shapeNodeWithEllipseOfSize:CGSizeMake(85,83)]; body.fillColor=Cream(); body.strokeColor=UIColor.whiteColor; body.lineWidth=3; body.position=CGPointMake(0,0); [launcher addChild:body];
            SKShapeNode *hole=[SKShapeNode shapeNodeWithCircleOfRadius:27]; hole.fillColor=[UIColor colorWithRed:.53 green:.35 blue:.50 alpha:1]; hole.strokeColor=[UIColor colorWithRed:.84 green:.65 blue:.70 alpha:1]; hole.lineWidth=5; hole.position=CGPointMake(0,8); [launcher addChild:hole];
        }
    }
    self.currentPiece=[SKNode node]; self.currentPiece.zPosition=12; [self.playfield addChild:self.currentPiece];
    self.wildLabel=[GummyUI label:@"" size:18 color:Cream()]; self.wildLabel.position=CGPointMake(814,90); self.wildLabel.zPosition=50; [self.hud addChild:self.wildLabel];
    self.statusLabel=[GummyUI label:@"" size:17 color:Cream()]; self.statusLabel.position=CGPointMake(588,190); self.statusLabel.zPosition=60; [self.hud addChild:self.statusLabel];
}
- (void)syncBoard {
#if DEBUG
    if(self.clockValidation) return;
#endif
    if(self.renderedRevision==self.engine.revision) return;
    NSMutableSet *keys=[NSMutableSet set];
    for(GDCell *cell in self.engine.cells){
        [keys addObject:cell.key]; SKNode *node=self.pieceNodes[cell.key];
        if(!node || [node.userData[@"color"] integerValue]!=cell.color){ [node removeFromParent]; node=[GummyUI piece:cell.color diameter:self.engine.radius*2-1]; node.userData=[@{@"color":@(cell.color)} mutableCopy]; [self.boardPieces addChild:node]; self.pieceNodes[cell.key]=node; }
        node.position=ScenePoint([self.engine centerOfCell:cell]); node.alpha=1; node.xScale=node.yScale=1;
    }
    for(NSString *key in self.pieceNodes.allKeys) if(![keys containsObject:key]){ [self.pieceNodes[key] removeFromParent]; [self.pieceNodes removeObjectForKey:key]; }
    self.renderedRevision=self.engine.revision;
}
- (void)refreshHUD {
    self.scoreLabel.text=[NSString stringWithFormat:@"%ld",(long)self.engine.score];
    BOOL frozen=self.engine.freezeRemaining>0;
    SKNode *frost=[self.playfield childNodeWithName:@"frozenBoardRim"];
    if(frozen && !frost){
        SKShapeNode *rim=[GummyUI panel:CGSizeMake(822,546) fill:[UIColor colorWithRed:.62 green:.90 blue:1 alpha:.035] stroke:[UIColor colorWithRed:.70 green:.96 blue:1 alpha:.85] radius:15];
        rim.name=@"frozenBoardRim"; rim.position=CGPointMake(588,324); rim.lineWidth=3; rim.glowWidth=3; rim.zPosition=12; [self.playfield addChild:rim];
        [rim runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction fadeAlphaTo:.55 duration:1.2],[SKAction fadeAlphaTo:.9 duration:1.2]]]]];
    } else if(!frozen) [frost removeFromParent];
    self.timerTitle.text=frozen?@"FROZEN":@"NEW ROW";
    NSTimeInterval remaining=frozen?self.engine.freezeRemaining:self.engine.pressureRemaining;
    NSInteger seconds=(NSInteger)ceil(MAX(0,remaining)); self.timerLabel.text=[NSString stringWithFormat:@"%02ld:%02ld",(long)(seconds/60),(long)(seconds%60)];
    self.modeLabel.text=self.engine.mode==GDGameModeLevel?[NSString stringWithFormat:@"LEVEL %02ld",(long)self.engine.levelID]:@"ENDLESS";
    if(self.engine.mode==GDGameModeLevel){
        NSArray *verbs=@[@"CLEAR WAVES",@"COLLECT",@"DROP",@"SURVIVE"];
        NSString *kind=verbs[self.engine.objective];
        if(self.engine.objective==GDObjectiveCollect) kind=[NSString stringWithFormat:@"%@ %@",kind,@[@"BLUE",@"RED",@"YELLOW",@"WHITE"][self.engine.objectiveColor]];
        self.objectiveLabel.text=[NSString stringWithFormat:@"%@  %ld / %ld%@   ·   WAVE %ld/%ld",kind,(long)self.engine.objectiveCurrent,(long)self.engine.objectiveTarget,self.engine.objective==GDObjectiveSurvive?@"s":@"",(long)self.engine.wave,(long)self.engine.totalWaves];
    } else self.objectiveLabel.text=[NSString stringWithFormat:@"WAVE %ld",(long)self.engine.wave];
    self.timerLabel.fontColor=frozen?[UIColor colorWithRed:.05 green:.45 blue:.73 alpha:1]:Ink();
    for(NSInteger i=0;i<4;i++){
        NSInteger energy=self.engine.energy[i].integerValue, threshold=[self.engine energyThresholdForColor:i]; CGFloat amount=MAX(0,MIN(1,(CGFloat)energy/threshold));
        CGPathRef path=CGPathCreateWithRoundedRect(CGRectMake(0,-5.5,MAX(1,106*amount),11),5,5,NULL); self.energyFills[i].path=path; CGPathRelease(path);
        self.energyLabels[i].text=energy>=threshold?@"READY":[NSString stringWithFormat:@"%ld/%ld",(long)energy,(long)threshold];
        self.energyLabels[i].fontColor=Ink();
        NSInteger previous=self.displayedEnergy[i].integerValue;
        if(energy>previous){
            [self pulse:self.energyFills[i] amount:1.13];
            [self floatingText:[NSString stringWithFormat:@"+%ld",(long)(energy-previous)] at:CGPointMake(126,552-i*146-11) color:[GummyUI color:i] size:17 layer:self.hud];
        }
        if(energy>=threshold && previous<threshold){ [self pulse:self.skillCards[i] amount:1.06]; [GDSettings.sharedSettings playFeedback:GDFeedbackReady]; }
        if(i==GDColorBlue && frozen) self.energyLabels[i].text=[NSString stringWithFormat:@"%.0fs",ceil(self.engine.freezeRemaining)];
        if(i==GDColorRed && self.engine.blastArmed) self.energyLabels[i].text=@"AIM";
        if(i==GDColorWhite && self.engine.wildRemaining>0) self.energyLabels[i].text=[NSString stringWithFormat:@"%ld SHOTS",(long)self.engine.wildRemaining];
        SKNode *ready=[self.skillCards[i] childNodeWithName:@"readyOutline"];
        if(energy>=threshold && !ready){ SKShapeNode *outline=[GummyUI panel:CGSizeMake(126,134) fill:UIColor.clearColor stroke:[GummyUI color:i] radius:19]; outline.name=@"readyOutline"; outline.lineWidth=3; outline.zPosition=3; [self.skillCards[i] addChild:outline]; }
        else if(energy<threshold) [ready removeFromParent];
        self.skillCards[i].alpha=self.engine.phase==GDPhaseReady?1:.7;
    }
    self.displayedEnergy=[self.engine.energy copy];
    for(NSInteger i=0;i<3;i++){ self.launcherNodes[i].alpha=self.engine.launcher==i?1:.80; [self.launcherNodes[i] childNodeWithName:@"activeGlow"].hidden=self.engine.launcher!=i; }
    if(self.displayedNext!=self.engine.nextColor){ [self.nextPiece removeAllChildren]; [self.nextPiece addChild:[GummyUI piece:self.engine.nextColor diameter:74]]; self.displayedNext=self.engine.nextColor; }
    if(self.displayedHeld!=self.engine.heldColor){ [self.heldPiece removeAllChildren]; if(self.engine.heldColor>=0) [self.heldPiece addChild:[GummyUI piece:self.engine.heldColor diameter:74]]; else { SKLabelNode *empty=[GummyUI label:@"+" size:37 color:[UIColor colorWithRed:.66 green:.52 blue:.64 alpha:1]]; [self.heldPiece addChild:empty]; } self.displayedHeld=self.engine.heldColor; }
    self.heldPiece.alpha=self.engine.holdUsed?.52:1; self.holdLabel.alpha=self.engine.holdUsed?.52:1;
    NSInteger shown=self.engine.blastArmed?GDColorRed:self.engine.currentColor;
    if(self.displayedCurrent!=shown){ [self.currentPiece removeAllChildren]; [self.currentPiece addChild:[GummyUI piece:shown diameter:54]]; self.displayedCurrent=shown; }
    self.currentPiece.position=ScenePoint([self.engine launcherPoint:self.engine.launcher]);
    self.currentPiece.hidden=self.engine.phase==GDPhaseFlying;
    self.wildLabel.text=self.engine.wildRemaining>0?[NSString stringWithFormat:@"★ ×%ld",(long)self.engine.wildRemaining]:@"";
    self.wildLabel.position=CGPointMake(self.currentPiece.position.x+92,93);
    BOOL wild=self.engine.wildRemaining>0 && !self.engine.blastArmed;
    SKNode *ring=[self.currentPiece childNodeWithName:@"wildRing"];
    if(wild && !ring){ SKShapeNode *r=[SKShapeNode shapeNodeWithCircleOfRadius:32]; r.name=@"wildRing"; r.strokeColor=UIColor.whiteColor; r.lineWidth=2.5; r.fillColor=UIColor.clearColor; [self.currentPiece addChild:r]; }
    if(!wild) [ring removeFromParent];
    SKNode *blastRing=[self.currentPiece childNodeWithName:@"blastRing"];
    if(self.engine.blastArmed && !blastRing){ SKShapeNode *r=[SKShapeNode shapeNodeWithCircleOfRadius:33]; r.name=@"blastRing"; r.strokeColor=[GummyUI color:GDColorRed]; r.lineWidth=3; r.fillColor=[[GummyUI color:GDColorRed] colorWithAlphaComponent:.12]; [self.currentPiece addChild:r]; }
    if(!self.engine.blastArmed) [blastRing removeFromParent];
    if(self.engine.blastArmed) self.statusLabel.text=@"BLAST  ·  Drag to aim";
    else if(self.yellowArmed) self.statusLabel.text=@"SWEEP  ·  Tap again to use";
    else if(!self.aiming) self.statusLabel.text=@"";
}
- (NSString *)controlAt:(CGPoint)point {
    if(self.overlay){
        for(NSString *control in self.overlayControls) if(CGRectContainsPoint(self.overlayControls[control].CGRectValue,point)) return control;
        return @"overlay";
    }
    if(CGRectContainsPoint(CGRectMake(1101,616,64,57),point)) return @"pause";
    for(NSInteger i=0;i<4;i++) if(CGRectContainsPoint(CGRectMake(15,483-i*146,134,138),point)) return [NSString stringWithFormat:@"skill%ld",(long)i];
    if(CGRectContainsPoint(CGRectMake(1040,256,140,155),point)) return @"hold";
    if(CGRectContainsPoint(CGRectMake(1040,417,140,164),point)) return @"next";
    if(point.y<143){ for(NSInteger i=0;i<3;i++){ CGPoint p=ScenePoint([self.engine launcherPoint:i]); if(fabs(p.x-point.x)<74 && fabs(p.y-point.y)<60) return [NSString stringWithFormat:@"launcher%ld",(long)i]; } }
    return nil;
}
- (void)handleControl:(NSString *)control {
#if DEBUG
    if(self.qaPresentationFixture && ![@[@"home",@"levels",@"allLevels",@"scores"] containsObject:control]) return;
#endif
    if(![control isEqualToString:@"overlay"] && ![control isEqualToString:@"next"]) [GDSettings.sharedSettings playFeedback:GDFeedbackTap];
    if([control isEqualToString:@"pause"]){ [self pauseGame]; return; }
    if([control isEqualToString:@"resume"]){ [self.overlay removeFromParent]; self.overlay=nil; [GummyUI setOverlayDimmed:NO]; self.playfield.paused=NO; [self.engine resume]; self.lastTime=0; [self refreshMusic]; [GDAudioFeedback.sharedPlayer resumeMusic]; return; }
    if([control isEqualToString:@"levels"] || [control isEqualToString:@"allLevels"]){ [self saveRun]; [self.view presentScene:[FrontendScene levelsScene]]; return; }
    if([control isEqualToString:@"scores"]){ [self.view presentScene:[FrontendScene leaderboardScene]]; return; }
    if([control isEqualToString:@"nextLevel"]){ NSInteger next=self.engine.levelID+1; if([GDLevelCatalog levelForID:next]){ GameScene *scene=[[GameScene alloc] initWithSize:self.size levelID:next]; scene.scaleMode=self.scaleMode; [self.view presentScene:scene]; } return; }
    if([control isEqualToString:@"retry"]){ [self restart]; return; }
    if([control isEqualToString:@"home"]){ [self goHome]; return; }
    if([control isEqualToString:@"settings"]){ [self.view presentScene:[FrontendScene settingsSceneReturningTo:self]]; return; }
    if(self.engine.phase!=GDPhaseReady) return;
    [self clearAim];
    if([control hasPrefix:@"launcher"]){ if([self.engine selectLauncher:[[control substringFromIndex:8] integerValue]]) [self pulse:self.launcherNodes[self.engine.launcher] amount:1.07]; self.yellowArmed=NO; }
    else if([control isEqualToString:@"hold"]){ if([self.engine hold]){ [self pulse:self.heldPiece amount:1.17]; [self pulse:self.currentPiece amount:1.13]; } self.yellowArmed=NO; }
    else if([control hasPrefix:@"skill"]){
        NSInteger i=[[control substringFromIndex:5] integerValue];
        if(i==GDColorYellow){
            if(self.yellowArmed){ self.yellowArmed=NO; GDEvent *event=[self.engine activateYellow]; if(event){ [GDSettings.sharedSettings playFeedback:GDFeedbackSweep]; [self animateEvent:event]; } }
            else if(self.engine.energy[GDColorYellow].integerValue>=[self.engine energyThresholdForColor:GDColorYellow]){ self.yellowArmed=YES; [self highlightCells:[self.engine yellowTargets] color:[GummyUI color:GDColorYellow]]; }
        } else { self.yellowArmed=NO; if([self.engine activateSkill:i]){ if(i!=GDColorRed || self.engine.blastArmed) [GDSettings.sharedSettings playFeedback:i==GDColorBlue?GDFeedbackFreeze:(i==GDColorRed?GDFeedbackBlastReady:GDFeedbackWild)]; [self skillEffect:i]; } }
    }
    [self refreshHUD];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(self.aimTouch) return;
    UITouch *touch=touches.anyObject; CGPoint p=[touch locationInNode:self]; NSString *control=[self controlAt:p];
    if([control hasPrefix:@"launcher"] && self.engine.phase==GDPhaseReady){
        [self handleControl:control]; self.aimTouch=touch; self.aimTouchStart=p; return;
    }
    if(control){ [self handleControl:control]; return; }
    if(self.engine.phase!=GDPhaseReady || self.aimTouch || p.x<174 || p.x>1002 || p.y<153 || p.y>607) return;
    self.yellowArmed=NO; self.aimTouch=touch; self.aimTouchStart=p; self.aiming=YES; [self updateAim:p];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(self.aimTouch && [touches containsObject:self.aimTouch]){
        CGPoint p=[self.aimTouch locationInNode:self];
        if(!self.aiming && hypot(p.x-self.aimTouchStart.x,p.y-self.aimTouchStart.y)<8) return;
        self.aiming=YES; [self updateAim:p];
    }
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(!self.aimTouch || ![touches containsObject:self.aimTouch]) return;
    CGPoint p=[self.aimTouch locationInNode:self];
    BOOL cancel=p.y<120 || p.x<160 || p.x>1016 || [self controlAt:p]!=nil;
    // The release may contain a final position that was never delivered as a move.
    // A cannon tap only selects it; a drag or a board touch establishes aiming.
    if(hypot(p.x-self.aimTouchStart.x,p.y-self.aimTouchStart.y)>=8) self.aiming=YES;
    if(!cancel && self.aiming) [self updateAim:p];
    GDShot *shot=self.aiming?self.preview:nil;
    [self clearAim];
    BOOL fired=!cancel && shot.valid && [self.engine beginShot:shot];
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-feedback"]){ CGPoint target=BoardPoint(p), start=[self.engine launcherPoint:self.engine.launcher]; NSLog(@"QA release launcher=%ld x=%.2f y=%.2f angle=%.2f cancelled=%d valid=%d fired=%d matches=%lu color=%ld bounced=%d",(long)self.engine.launcher,p.x,p.y,atan2(target.x-start.x,start.y-target.y)*180/M_PI,cancel,shot.valid,fired,(unsigned long)shot.expectedMatches.count,(long)shot.resolvedColor,shot.bounced); }
#endif
    if(fired) [self flyShot:shot];
    else if(self.engine.blastArmed) [self.engine cancelBlast];
    [self refreshHUD];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(!self.aimTouch || ![touches containsObject:self.aimTouch]) return;
    [self clearAim]; [self.engine cancelBlast]; [self refreshHUD];
}
- (void)clearAim { self.aiming=NO; self.aimTouch=nil; self.preview=nil; [self.aimLayer removeAllChildren]; self.statusLabel.text=@""; }
- (void)updateAim:(CGPoint)point {
    [self.aimLayer removeAllChildren];
    if(self.engine.phase!=GDPhaseReady){ self.preview=nil; return; }
    self.preview=[self.engine previewToward:BoardPoint(point)];
    UIColor *color=self.preview.valid?[UIColor colorWithRed:.54 green:.91 blue:1 alpha:1]:[UIColor colorWithRed:1 green:.5 blue:.55 alpha:1];
    if(!GDSettings.sharedSettings.aimGuideEnabled){
        self.statusLabel.text=self.preview.valid?(self.engine.blastArmed?@"BLAST":@""):@"Drag up to aim";
#if DEBUG
        if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-feedback"]) NSLog(@"QA aim guide enabled=0 nodes=%lu valid=%d",(unsigned long)self.aimLayer.children.count,self.preview.valid);
#endif
        return;
    }
    NSArray<NSValue *> *points=self.preview.points;
    for(NSInteger i=1;i<points.count;i++){
        CGPoint a=ScenePoint(points[i-1].CGPointValue),b=ScenePoint(points[i].CGPointValue); CGFloat len=hypot(b.x-a.x,b.y-a.y);
        for(CGFloat d=10;d<len;d+=14){ CGFloat t=d/len; SKShapeNode *dot=[SKShapeNode shapeNodeWithCircleOfRadius:2.2]; dot.fillColor=color; dot.strokeColor=UIColor.clearColor; dot.position=CGPointMake(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t); [self.aimLayer addChild:dot]; }
        if(i<points.count-1){ SKShapeNode *bounce=[SKShapeNode shapeNodeWithCircleOfRadius:6]; bounce.strokeColor=color; bounce.lineWidth=2; bounce.fillColor=[color colorWithAlphaComponent:.15]; bounce.position=b; [self.aimLayer addChild:bounce]; }
    }
    if(self.preview.valid && !self.preview.blast){
        GDCell *landing=[GDCell row:self.preview.landingRow column:self.preview.landingColumn color:self.preview.resolvedColor];
        CGPoint p=ScenePoint([self.engine centerOfCell:landing]); SKNode *ghost=[GummyUI piece:self.preview.resolvedColor diameter:45]; ghost.alpha=.45; ghost.position=p; [self.aimLayer addChild:ghost];
        SKShapeNode *circle=[SKShapeNode shapeNodeWithCircleOfRadius:24]; circle.position=p; circle.fillColor=UIColor.clearColor; circle.strokeColor=UIColor.whiteColor; circle.lineWidth=2.2; [self.aimLayer addChild:circle];
        [self highlightCells:self.preview.expectedMatches color:color];
        self.statusLabel.text=self.engine.wildRemaining>0?[NSString stringWithFormat:@"WILD  ·  %ld match",(long)self.preview.expectedMatches.count]:@"";
    } else if(self.preview.valid && self.preview.hitCell){
        CGPoint p=ScenePoint([self.engine centerOfCell:self.preview.hitCell]); SKShapeNode *blast=[SKShapeNode shapeNodeWithCircleOfRadius:self.engine.blastRadius+self.engine.radius]; blast.position=p; blast.strokeColor=[GummyUI color:GDColorRed]; blast.fillColor=[[GummyUI color:GDColorRed] colorWithAlphaComponent:.14]; blast.lineWidth=2; [self.aimLayer addChild:blast]; [self highlightCells:self.preview.expectedMatches color:[GummyUI color:GDColorRed]]; self.statusLabel.text=@"BLAST";
    } else self.statusLabel.text=@"Drag up to aim  ·  Release below cannons to cancel";
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-feedback"]) NSLog(@"QA aim guide enabled=1 nodes=%lu valid=%d",(unsigned long)self.aimLayer.children.count,self.preview.valid);
#endif
}
- (void)highlightCells:(NSArray<GDCell *> *)cells color:(UIColor *)color {
    for(GDCell *cell in cells){ SKShapeNode *ring=[SKShapeNode shapeNodeWithCircleOfRadius:24]; ring.position=ScenePoint([self.engine centerOfCell:cell]); ring.strokeColor=color; ring.fillColor=[color colorWithAlphaComponent:.12]; ring.lineWidth=2.5; [self.aimLayer addChild:ring]; }
}
- (void)flyShot:(GDShot *)shot {
    if(shot.blast) self.blastImpactPoint=shot.hitCell?ScenePoint([self.engine centerOfCell:shot.hitCell]):ScenePoint(shot.points.lastObject.CGPointValue);
    [GDSettings.sharedSettings playFeedback:GDFeedbackShot intensity:.5 color:shot.blast?GDColorRed:self.engine.currentColor];
    SKNode *projectile=[GummyUI piece:shot.blast?GDColorRed:self.engine.currentColor diameter:45]; projectile.position=ScenePoint(shot.points.firstObject.CGPointValue); [self.effects addChild:projectile];
    NSMutableArray *actions=[NSMutableArray array];
    NSTimeInterval trailTime=0;
    for(NSInteger i=1;i<shot.points.count;i++){
        CGPoint a=ScenePoint(shot.points[i-1].CGPointValue), b=ScenePoint(shot.points[i].CGPointValue); CGFloat length=hypot(b.x-a.x,b.y-a.y);
        for(CGFloat d=35;d<length;d+=48){ SKShapeNode *dot=[SKShapeNode shapeNodeWithCircleOfRadius:4]; dot.fillColor=[[GummyUI color:shot.blast?GDColorRed:self.engine.currentColor] colorWithAlphaComponent:.55]; dot.strokeColor=UIColor.clearColor; dot.position=CGPointMake(a.x+(b.x-a.x)*d/length,a.y+(b.y-a.y)*d/length); dot.hidden=YES; [self.effects addChild:dot]; [dot runAction:[SKAction sequence:@[[SKAction waitForDuration:trailTime+d/1250.],[SKAction unhide],[SKAction group:@[[SKAction scaleTo:.1 duration:.17],[SKAction fadeOutWithDuration:.17]]],[SKAction removeFromParent]]]]; }
        trailTime+=length/1250.;
    }
    for(NSInteger i=1;i<shot.points.count;i++){ CGPoint a=shot.points[i-1].CGPointValue,b=shot.points[i].CGPointValue; NSTimeInterval duration=hypot(b.x-a.x,b.y-a.y)/1250.; [actions addObject:[SKAction moveTo:ScenePoint(b) duration:duration]]; }
    self.flightRemaining=0;
    for(SKAction *action in actions) self.flightRemaining+=action.duration;
    [actions addObject:[SKAction removeFromParent]];
    [self recoilLauncher];

    [projectile runAction:[SKAction sequence:actions]];
}
- (void)pulse:(SKNode *)node amount:(CGFloat)amount {
    [node removeActionForKey:@"pulse"]; node.xScale=node.yScale=1;
    SKAction *grow=[SKAction scaleTo:amount duration:.10]; grow.timingMode=SKActionTimingEaseOut;
    [node runAction:[SKAction sequence:@[grow,[SKAction scaleTo:.98 duration:.10],[SKAction scaleTo:1 duration:.12]]] withKey:@"pulse"];
}
- (void)floatingText:(NSString *)text at:(CGPoint)p color:(UIColor *)color size:(CGFloat)size layer:(SKNode *)layer {
    SKLabelNode *label=[GummyUI label:text size:size color:color]; label.position=p; label.name=@"feedback"; label.zPosition=90; [layer addChild:label];
    [label runAction:[SKAction sequence:@[[SKAction group:@[[SKAction moveByX:0 y:25 duration:.58],[SKAction sequence:@[[SKAction waitForDuration:.18],[SKAction fadeOutWithDuration:.4]]]]],[SKAction removeFromParent]]]];
}
- (void)burstAt:(CGPoint)p radius:(CGFloat)radius color:(UIColor *)color {
    SKShapeNode *ring=[SKShapeNode shapeNodeWithCircleOfRadius:radius]; ring.position=p; ring.strokeColor=color; ring.fillColor=UIColor.clearColor; ring.lineWidth=3; ring.alpha=.9; ring.zPosition=10; [self.effects addChild:ring];
    [ring runAction:[SKAction sequence:@[[SKAction group:@[[SKAction scaleTo:1.9 duration:.3],[SKAction fadeOutWithDuration:.3]]],[SKAction removeFromParent]]]];
}
- (void)recoilLauncher {
    SKNode *launcher=self.launcherNodes[self.engine.launcher];
    [launcher removeActionForKey:@"recoil"]; launcher.xScale=launcher.yScale=1;
    [launcher runAction:[SKAction sequence:@[[SKAction group:@[[SKAction scaleXTo:1.12 duration:.06],[SKAction scaleYTo:.86 duration:.06]]],[SKAction group:@[[SKAction scaleXTo:.97 duration:.12],[SKAction scaleYTo:1.06 duration:.12]]],[SKAction scaleTo:1 duration:.13]]] withKey:@"recoil"];
    [self burstAt:self.currentPiece.position radius:25 color:Cream()];
}
- (SKNode *)iceCrystal:(CGFloat)size {
    CGMutablePathRef path=CGPathCreateMutable();
    for(NSInteger arm=0;arm<6;arm++){
        CGFloat angle=arm*M_PI/3, x=cos(angle), y=sin(angle);
        CGPathMoveToPoint(path,NULL,0,0); CGPathAddLineToPoint(path,NULL,x*size,y*size);
        for(NSInteger side=-1;side<=1;side+=2){
            CGPathMoveToPoint(path,NULL,x*size*.55,y*size*.55);
            CGPathAddLineToPoint(path,NULL,x*size*.55+cos(angle+side*M_PI/3)*size*.31,y*size*.55+sin(angle+side*M_PI/3)*size*.31);
        }
    }
    SKShapeNode *crystal=[SKShapeNode shapeNodeWithPath:path]; CGPathRelease(path);
    crystal.strokeColor=[UIColor colorWithRed:.85 green:.99 blue:1 alpha:1]; crystal.lineWidth=1.8; crystal.glowWidth=1.5;
    return crystal;
}
- (void)explodeAt:(CGPoint)point radius:(CGFloat)radius {
    CGFloat reach=radius+self.engine.radius;
    SKShapeNode *flash=[SKShapeNode shapeNodeWithCircleOfRadius:radius*.48]; flash.position=point;
    flash.fillColor=[UIColor colorWithRed:1 green:.88 blue:.39 alpha:.9]; flash.strokeColor=[UIColor colorWithRed:1 green:.48 blue:.15 alpha:1]; flash.glowWidth=8;
    flash.xScale=flash.yScale=.2; flash.zPosition=4; [self.effects addChild:flash];
    [flash runAction:[SKAction sequence:@[[SKAction scaleTo:1 duration:.055],[SKAction group:@[[SKAction scaleTo:1.3 duration:.16],[SKAction fadeOutWithDuration:.16]]],[SKAction removeFromParent]]]];
    for(NSInteger wave=0;wave<2;wave++){
        SKShapeNode *shock=[SKShapeNode shapeNodeWithCircleOfRadius:reach]; shock.position=point;
        shock.strokeColor=wave?[GummyUI color:GDColorRed]:[UIColor colorWithRed:1 green:.69 blue:.19 alpha:1]; shock.fillColor=UIColor.clearColor;
        shock.lineWidth=wave?3:6; shock.glowWidth=3; shock.xScale=shock.yScale=.15; shock.alpha=0; [self.effects addChild:shock];
        SKAction *expand=[SKAction scaleTo:1 duration:.30]; expand.timingMode=SKActionTimingEaseOut;
        [shock runAction:[SKAction sequence:@[[SKAction waitForDuration:wave*.045],[SKAction fadeAlphaTo:.95 duration:.015],[SKAction group:@[expand,[SKAction fadeOutWithDuration:.30]]],[SKAction removeFromParent]]]];
    }
    for(NSInteger i=0;i<16;i++){
        CGFloat angle=i*2*M_PI/16+.13, distance=reach*(.55+(i%4)*.11);
        SKShapeNode *spark=[GummyUI panel:CGSizeMake(10+(i%3)*3,3.5) fill:[UIColor colorWithRed:1 green:.70+(i%2)*.15 blue:.25 alpha:1] stroke:UIColor.clearColor radius:1.7];
        spark.position=point; spark.zRotation=angle; spark.glowWidth=2; [self.effects addChild:spark];
        SKAction *eject=[SKAction moveByX:cos(angle)*distance y:sin(angle)*distance duration:.38]; eject.timingMode=SKActionTimingEaseOut;
        [spark runAction:[SKAction sequence:@[[SKAction group:@[eject,[SKAction scaleTo:.15 duration:.38],[SKAction sequence:@[[SKAction waitForDuration:.10],[SKAction fadeOutWithDuration:.28]]]]],[SKAction removeFromParent]]]];
    }
    for(NSInteger i=0;i<6;i++){
        CGFloat angle=i*M_PI/3;
        SKShapeNode *smoke=[SKShapeNode shapeNodeWithCircleOfRadius:radius*.18]; smoke.position=point;
        smoke.fillColor=[UIColor colorWithRed:.73 green:.28 blue:.24 alpha:.24]; smoke.strokeColor=UIColor.clearColor; smoke.zPosition=-1; [self.effects addChild:smoke];
        [smoke runAction:[SKAction sequence:@[[SKAction group:@[[SKAction moveByX:cos(angle)*radius*.55 y:sin(angle)*radius*.55 duration:.50],[SKAction scaleTo:2 duration:.50],[SKAction fadeOutWithDuration:.50]]],[SKAction removeFromParent]]]];
    }
}
- (void)skillEffect:(NSInteger)color {
    [self pulse:self.skillCards[color] amount:1.07];
    if(color==GDColorBlue){
        SKShapeNode *mist=[GummyUI panel:CGSizeMake(822,546) fill:[UIColor colorWithRed:.57 green:.88 blue:1 alpha:.16] stroke:[UIColor colorWithRed:.79 green:.98 blue:1 alpha:.9] radius:15];
        mist.position=CGPointMake(588,324); mist.lineWidth=5; mist.glowWidth=3; [self.effects addChild:mist];
        [mist runAction:[SKAction sequence:@[[SKAction fadeAlphaTo:.9 duration:.08],[SKAction fadeOutWithDuration:.65],[SKAction removeFromParent]]]];
        NSArray<GDCell *> *cells=self.engine.cells; NSInteger stride=MAX(1,(cells.count+35)/36);
        for(NSInteger i=0;i<cells.count;i+=stride){
            CGPoint point=ScenePoint([self.engine centerOfCell:cells[i]]); SKNode *crystal=[self iceCrystal:12+(i%3)*2]; crystal.position=point;
            crystal.alpha=0; crystal.xScale=crystal.yScale=.25; [self.effects addChild:crystal];
            NSTimeInterval delay=MAX(0,(point.x-174)/828)*.12;
            [crystal runAction:[SKAction sequence:@[[SKAction waitForDuration:delay],[SKAction group:@[[SKAction fadeAlphaTo:1 duration:.04],[SKAction scaleTo:1.05 duration:.18]]],[SKAction group:@[[SKAction moveByX:0 y:10 duration:.45],[SKAction fadeOutWithDuration:.45]]],[SKAction removeFromParent]]]];
        }
    } else if(color==GDColorWhite){
        for(NSInteger i=0;i<self.engine.wildRemaining;i++){ SKNode *star=[GummyUI image:@"wild_icon" size:CGSizeMake(18,18)]; if(!star) continue; star.position=CGPointMake(self.currentPiece.position.x+(i-(self.engine.wildRemaining-1)/2.0)*27,self.currentPiece.position.y+40); [self.effects addChild:star]; [star runAction:[SKAction sequence:@[[SKAction group:@[[SKAction moveByX:0 y:24 duration:.5],[SKAction fadeOutWithDuration:.5]]],[SKAction removeFromParent]]]]; }
    } else if(color==GDColorRed && self.engine.blastArmed){
        [self burstAt:self.currentPiece.position radius:31 color:[UIColor colorWithRed:1 green:.63 blue:.18 alpha:1]];
        for(NSInteger i=0;i<5;i++){
            SKShapeNode *spark=[SKShapeNode shapeNodeWithCircleOfRadius:2.8]; spark.fillColor=[UIColor colorWithRed:1 green:.79 blue:.24 alpha:1]; spark.strokeColor=UIColor.clearColor;
            spark.position=CGPointMake(self.currentPiece.position.x,self.currentPiece.position.y+24); [self.effects addChild:spark];
            [spark runAction:[SKAction sequence:@[[SKAction group:@[[SKAction moveByX:(i-2)*13 y:24+(i%3)*8 duration:.28],[SKAction fadeOutWithDuration:.28]]],[SKAction removeFromParent]]]];
        }
    }
}
- (void)animateEvent:(GDEvent *)event {
#if DEBUG
    if(self.clockValidation){ self.resolutionRemaining=.38; return; }
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-feedback"]) NSLog(@"QA event source=%ld removed=%lu fallen=%lu points=%ld score=%ld objective=%ld/%ld phase=%ld",(long)event.source,(unsigned long)event.removed.count,(unsigned long)event.fallen.count,(long)event.points,(long)self.engine.score,(long)self.engine.objectiveCurrent,(long)self.engine.objectiveTarget,(long)self.engine.phase);
    if(event.source==GDSourceBlast && [NSProcessInfo.processInfo.arguments containsObject:@"-qa-blast-art"]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.10*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ self.paused=YES; NSLog(@"QA skill blast captured impact=(%.1f,%.1f) radius=%.1f removed=%lu",self.blastImpactPoint.x,self.blastImpactPoint.y,self.engine.blastRadius,(unsigned long)event.removed.count); });
#endif
    [self clearAim]; self.yellowArmed=NO;
    NSInteger count=event.removed.count+event.fallen.count;
    if(event.source==GDSourceNormal || event.source==GDSourceWild){
        if(count){
            self.combo++;
            CGFloat intensity=MIN(1,.35+count/30.0);
            if(event.removed.count) [GDSettings.sharedSettings playFeedback:GDFeedbackMatch intensity:intensity color:event.placed?event.placed.color:event.removed.firstObject.color];
            if(GDSettings.sharedSettings.soundEffectsEnabled){
                if(event.fallen.count) [GDAudioFeedback.sharedPlayer playFeedback:GDFeedbackFall intensity:intensity];
                if(self.combo>1 || count>=10) [GDAudioFeedback.sharedPlayer playFeedback:GDFeedbackCombo intensity:intensity];
            }
        }
        else self.combo=0;
    } else if(event.source==GDSourceBlast) [GDSettings.sharedSettings playFeedback:GDFeedbackBlast];

    CGPoint center=CGPointZero;
    for(GDCell *cell in event.removed){ CGPoint p=ScenePoint([self.engine centerOfCell:cell rowPhase:event.rowPhase]); center.x+=p.x; center.y+=p.y; }
    if(event.source==GDSourceBlast) [self explodeAt:self.blastImpactPoint radius:self.engine.blastRadius];
    else if(event.removed.count){ center.x/=event.removed.count; center.y/=event.removed.count; [self burstAt:center radius:24 color:Cream()]; }
    if(event.source==GDSourceYellow && event.removed.count){
        CGFloat minY=680,maxY=0; for(GDCell *cell in event.removed){ CGFloat y=ScenePoint([self.engine centerOfCell:cell rowPhase:event.rowPhase]).y; minY=MIN(minY,y); maxY=MAX(maxY,y); }
        SKShapeNode *sweep=[GummyUI panel:CGSizeMake(808,maxY-minY+46) fill:[[GummyUI color:GDColorYellow] colorWithAlphaComponent:.10] stroke:[GummyUI color:GDColorYellow] radius:15]; sweep.position=CGPointMake(588,(minY+maxY)/2); sweep.lineWidth=3; [self.effects addChild:sweep];
        [sweep runAction:[SKAction sequence:@[[SKAction group:@[[SKAction scaleYTo:.1 duration:.32],[SKAction fadeOutWithDuration:.32]]],[SKAction removeFromParent]]]];
    }
    NSInteger index=0;
    for(GDCell *cell in event.removed){
        SKNode *node=self.pieceNodes[cell.key]; if(!node) continue; [self.pieceNodes removeObjectForKey:cell.key]; CGPoint position=node.position; [node removeFromParent]; [self.effects addChild:node]; node.position=position;
        [node runAction:[SKAction sequence:@[[SKAction waitForDuration:MIN(.09,index*.008)],[SKAction group:@[[SKAction scaleXTo:1.24 duration:.06],[SKAction scaleYTo:.73 duration:.06]]],[SKAction scaleTo:1.13 duration:.07],[SKAction group:@[[SKAction scaleTo:.05 duration:.17],[SKAction fadeOutWithDuration:.17]]],[SKAction removeFromParent]]]];
        if(index++<30) for(NSInteger i=0;i<2;i++){ SKShapeNode *crumb=[SKShapeNode shapeNodeWithCircleOfRadius:3]; crumb.fillColor=[GummyUI color:cell.color]; crumb.strokeColor=UIColor.clearColor; crumb.position=position; [self.effects addChild:crumb]; CGFloat angle=(i*3.14)+cell.column*.7; [crumb runAction:[SKAction sequence:@[[SKAction group:@[[SKAction moveByX:cos(angle)*32 y:sin(angle)*32 duration:.28],[SKAction fadeOutWithDuration:.28]]],[SKAction removeFromParent]]]]; }
    }
    for(GDCell *cell in event.fallen){
        SKNode *node=self.pieceNodes[cell.key]; if(!node) continue; [self.pieceNodes removeObjectForKey:cell.key]; CGPoint position=node.position; [node removeFromParent]; [self.effects addChild:node]; node.position=position;
        SKAction *fall=[SKAction moveByX:(cell.column%5-2)*13 y:-170 duration:.46]; fall.timingMode=SKActionTimingEaseIn;
        [node runAction:[SKAction sequence:@[[SKAction waitForDuration:(cell.column%4)*.013],[SKAction scaleTo:1.06 duration:.05],[SKAction group:@[fall,[SKAction rotateByAngle:(cell.column%2?.7:-.7) duration:.46],[SKAction sequence:@[[SKAction waitForDuration:.17],[SKAction fadeOutWithDuration:.29]]]]],[SKAction removeFromParent]]]];
    }
    if(event.pushed){ for(SKNode *node in self.pieceNodes.allValues) [node runAction:[SKAction moveByX:0 y:-self.engine.radius*sqrt(3) duration:.20]]; self.renderedRevision=-1; }
    else [self syncBoard];
    if(event.placed){ SKNode *node=self.pieceNodes[event.placed.key]; [node runAction:[SKAction sequence:@[[SKAction group:@[[SKAction scaleXTo:1.15 duration:.06],[SKAction scaleYTo:.8 duration:.06]]],[SKAction group:@[[SKAction scaleXTo:.97 duration:.09],[SKAction scaleYTo:1.06 duration:.09]]],[SKAction scaleTo:1 duration:.12]]]]; }
    if(event.points>0){ [self pulse:self.scoreLabel amount:1.12]; [self floatingText:[NSString stringWithFormat:@"+%ld",(long)event.points] at:CGPointMake(325,608) color:Ink() size:23 layer:self.hud]; }
    if(self.combo>1 && count && (event.source==GDSourceNormal || event.source==GDSourceWild)) [self floatingText:[NSString stringWithFormat:@"COMBO %ld",(long)self.combo] at:CGPointMake(588,198) color:Cream() size:22 layer:self.effects];
    if(event.fallen.count>=6) [self floatingText:[NSString stringWithFormat:@"DROP +%lu",(unsigned long)event.fallen.count] at:CGPointMake(810,199) color:[GummyUI color:GDColorYellow] size:18 layer:self.effects];
    [self refreshHUD]; self.resolutionRemaining=.38;
}
- (void)update:(NSTimeInterval)currentTime {
    NSTimeInterval delta=self.lastTime>0?MIN(.25,MAX(0,currentTime-self.lastTime)):0; self.lastTime=currentTime;
    [self advanceGameClock:delta];
    [self refreshHUD];
    [self refreshMusic];
    if([self finished] && !self.overlay) [self showOverlay:YES];
}
- (void)refreshMusic {
    if(!self.view) return;
    if(self.engine.phase==GDPhasePaused){ [GDAudioFeedback.sharedPlayer pauseMusic]; return; }
    if([self finished]){ [GDAudioFeedback.sharedPlayer setMusicMode:GDMusicSilent]; return; }
    CGFloat clearance=self.engine.dangerY;
    for(GDCell *cell in self.engine.cells) clearance=MIN(clearance,self.engine.dangerY-([self.engine centerOfCell:cell].y+self.engine.radius));
    CGFloat rowHeight=self.engine.radius*sqrt(3);
    // Enter within two pressure rows; recover beyond three to avoid rapid toggles.
    if(self.engine.freezeRemaining>0) self.musicDanger=NO;
    else if(clearance<=2*rowHeight) self.musicDanger=YES;
    else if(clearance>3*rowHeight) self.musicDanger=NO;
    [GDAudioFeedback.sharedPlayer setMusicMode:self.musicDanger?GDMusicDanger:GDMusicRelaxed];
}
- (void)advanceGameClock:(NSTimeInterval)delta {
    // Split at authoritative phase boundaries so a long frame cannot shorten
    // flight/resolution or count its remaining time in the wrong phase.
    NSTimeInterval remaining=delta;
    for(NSInteger boundary=0;boundary<8 && remaining>0 && self.engine.phase!=GDPhasePaused && ![self finished];boundary++){
        BOOL flying=self.flightRemaining>=0 && self.engine.phase==GDPhaseFlying;
        BOOL resolving=self.resolutionRemaining>=0 && self.engine.phase==GDPhaseResolving;
        NSTimeInterval interval=flying?self.flightRemaining:(resolving?self.resolutionRemaining:remaining);
        NSTimeInterval step=MIN(remaining,MAX(0,interval));
        if(self.engine.phase==GDPhaseReady){
            NSTimeInterval pressureDeadline=self.engine.freezeRemaining+MAX(0,self.engine.pressureRemaining);
            step=MIN(step,MAX(.0000001,pressureDeadline));
            if(self.engine.mode==GDGameModeLevel && self.engine.objective==GDObjectiveSurvive) step=MIN(step,MAX(.0000001,self.engine.objectiveTarget-self.engine.elapsed));
        }
        GDEvent *event=step>0?[self.engine advanceTime:step]:nil;
        remaining-=step;
        if(flying){
            self.flightRemaining-=step;
            if(self.flightRemaining<=.000001){ self.flightRemaining=-1; GDEvent *resolved=[self.engine resolveShot]; if(resolved) [self animateEvent:resolved]; }
        } else if(resolving){
            self.resolutionRemaining-=step;
            if(self.resolutionRemaining<=.000001){ self.resolutionRemaining=-1; [self syncBoard]; GDEvent *next=[self.engine finishResolution]; if(next) [self animateEvent:next]; }
        }
        if(event) [self animateEvent:event];
    }
}
#if DEBUG
- (void)captureSkillArt {
    BOOL freeze=[NSProcessInfo.processInfo.arguments containsObject:@"-qa-freeze-art"];
    [self handleControl:freeze?@"skill0":@"skill1"];
    self.qaPresentationFixture=YES; // This render fixture must never overwrite a player's run.
    if(freeze){
        NSAssert(self.engine.freezeRemaining>0,@"Freeze art must come from a real skill activation");
        [self.engine pause];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.18*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            self.paused=YES; NSAssert([self.playfield childNodeWithName:@"frozenBoardRim"],@"Frozen board must retain its frost rim");
            NSLog(@"QA skill freeze captured remaining=%.1f",self.engine.freezeRemaining);
        });
    } else {
        GDShot *best=nil; CGPoint bestTarget=CGPointZero;
        for(CGFloat x=20;x<self.engine.boardWidth;x+=20){ GDShot *shot=[self.engine previewToward:CGPointMake(x,0)]; if(shot.valid && shot.hitCell && (!best || shot.expectedMatches.count>best.expectedMatches.count)){ best=shot; bestTarget=CGPointMake(x,0); } }
        // beginShot accepts only the latest preview, so refresh the selected target.
        best=[self.engine previewToward:bestTarget];
        NSAssert(best.blast && [self.engine beginShot:best],@"Blast art must use a real, valid blast shot");
        [self flyShot:best];
    }
}
- (void)validateMusicTransitions {
    GDEngine *original=self.engine; BOOL originalDanger=self.musicDanger;
    self.engine=[[GDEngine alloc] initWithSeed:20261008];
    for(NSNumber *depth in @[@8,@7,@6]) {
        NSMutableArray *cells=[NSMutableArray array];
        for(NSInteger row=0;row<=depth.integerValue;row++) [cells addObject:[GDCell row:row column:8 color:GDColorBlue]];
        [self.engine loadFixture:cells phase:0 current:GDColorBlue next:GDColorRed];
        [self refreshMusic];
        NSInteger expected=depth.integerValue==6?GDMusicRelaxed:GDMusicDanger;
        NSAssert([GDAudioFeedback.sharedPlayer.qaAudioState[@"mode"] integerValue]==expected,@"Music must track danger geometry and recovery hysteresis");
    }
    NSMutableArray *cells=[NSMutableArray array];
    for(NSInteger row=0;row<=8;row++) [cells addObject:[GDCell row:row column:8 color:GDColorBlue]];
    [self.engine loadFixture:cells phase:0 current:GDColorBlue next:GDColorRed];
    [self.engine setFixtureEnergy:@[@20,@0,@0,@0]];
    [self.engine activateSkill:GDColorBlue]; [self refreshMusic];
    NSAssert([GDAudioFeedback.sharedPlayer.qaAudioState[@"mode"] integerValue]==GDMusicRelaxed,@"Freeze must relax the danger arrangement");
    [self.engine advanceTime:30]; [self refreshMusic];
    NSAssert([GDAudioFeedback.sharedPlayer.qaAudioState[@"mode"] integerValue]==GDMusicDanger,@"Expired freeze must restore danger music");
    [self.engine pause]; [self refreshMusic];
    NSAssert(![GDAudioFeedback.sharedPlayer.qaAudioState[@"playing"] boolValue],@"Paused game must silence music");
    [self.engine resume]; [self refreshMusic]; [GDAudioFeedback.sharedPlayer resumeMusic];
    NSAssert([GDAudioFeedback.sharedPlayer.qaAudioState[@"playing"] boolValue],@"Game resume must resume the danger arrangement");
    NSMutableDictionary *terminal=[self.engine.snapshot mutableCopy]; terminal[@"gameOver"]=@YES; terminal[@"completionRecorded"]=@YES;
    self.engine=[[GDEngine alloc] initWithSnapshot:terminal]; [self refreshMusic];
    NSAssert(![GDAudioFeedback.sharedPlayer.qaAudioState[@"playing"] boolValue],@"Game Over must stop music");
    self.engine=original; self.musicDanger=originalDanger; [self refreshMusic];
    [self.engine pause]; self.playfield.paused=YES; [self refreshMusic]; [self showOverlay:NO];
    NSLog(@"QA music gameplay PASS danger hysteresis freeze expire pause resume gameOver");
}
- (GameScene *)clockProbe {
    GameScene *probe=[[GameScene alloc] initWithSize:self.size runSnapshot:nil];
    probe.clockValidation=YES; probe.engine=[[GDEngine alloc] initWithSeed:20260930];
    NSMutableArray *safeBoard=[NSMutableArray array]; for(GDCell *cell in probe.engine.cells) if(cell.row<3) [safeBoard addObject:cell];
    [probe.engine loadFixture:safeBoard phase:probe.engine.rowPhase current:GDColorBlue next:GDColorYellow];
    probe.flightRemaining=probe.resolutionRemaining=-1; return probe;
}
- (BOOL)probeStartShot:(GameScene *)probe {
    GDShot *shot=[probe.engine previewToward:CGPointMake(414,280)];
    if(!shot.valid || ![probe.engine beginShot:shot]) return NO;
    probe.flightRemaining=0;
    for(NSInteger i=1;i<shot.points.count;i++){ CGPoint a=shot.points[i-1].CGPointValue,b=shot.points[i].CGPointValue; probe.flightRemaining+=hypot(b.x-a.x,b.y-a.y)/1250.; }
    return YES;
}
- (NSDictionary *)probeSnapshotWithStep:(NSTimeInterval)step jitter:(BOOL)jitter {
    GameScene *probe=[self clockProbe]; NSTimeInterval time=0; NSInteger shotIndex=0,frame=0;
    while(time<13-.000001){
        if(shotIndex<5 && fabs(time-shotIndex*1.2)<.000001){ [self probeStartShot:probe]; shotIndex++; }
        NSTimeInterval next=shotIndex<5?shotIndex*1.2:13;
        NSTimeInterval amount=jitter?[@[@(.004),@(.033),@(.011),@(.072)][frame++%4] doubleValue]:step;
        amount=MIN(amount,MIN(next-time,13-time)); [probe advanceGameClock:amount]; time+=amount;
    }
    NSMutableDictionary *snapshot=[probe.engine.snapshot mutableCopy];
    [snapshot removeObjectsForKeys:@[@"runID",@"operations",@"elapsed",@"difficulty",@"pressure"]];
    return @{@"state":snapshot,@"elapsed":@(probe.engine.elapsed),@"pressure":@(probe.engine.pressureRemaining),@"phase":@(probe.engine.phase)};
}
- (void)validatePresentationClock {
    NSArray *preferenceKeys=@[@"GDPrototypeBestScore",@"GDPrototypeLastRun",@"GDEndlessRecords",@"GDCampaignProgress"];
    NSMutableDictionary *originalPreferences=[NSMutableDictionary dictionary];
    for(NSString *key in preferenceKeys) originalPreferences[key]=[NSUserDefaults.standardUserDefaults objectForKey:key]?:NSNull.null;
    NSDictionary *sixty=[self probeSnapshotWithStep:1./60 jitter:NO], *hundredTwenty=[self probeSnapshotWithStep:1./120 jitter:NO], *jitter=[self probeSnapshotWithStep:0 jitter:YES];
    BOOL equal=[sixty[@"state"] isEqual:hundredTwenty[@"state"]] && [sixty[@"state"] isEqual:jitter[@"state"]] && [sixty[@"phase"] isEqual:hundredTwenty[@"phase"]] && [sixty[@"phase"] isEqual:jitter[@"phase"]];
    for(NSString *key in @[@"elapsed",@"pressure"]) equal=equal && fabs([sixty[key] doubleValue]-[hundredTwenty[key] doubleValue])<.000001 && fabs([sixty[key] doubleValue]-[jitter[key] doubleValue])<.000001;
    GameScene *probe=[self clockProbe]; BOOL shot=[self probeStartShot:probe]; [probe advanceGameClock:probe.flightRemaining/2];
    NSTimeInterval flight=probe.flightRemaining; NSDictionary *before=probe.engine.snapshot; [probe.engine pause]; [probe advanceGameClock:2]; BOOL flightPause=[before isEqual:probe.engine.snapshot] && probe.flightRemaining==flight; [probe.engine resume];
    [probe advanceGameClock:probe.flightRemaining+.05]; NSTimeInterval resolution=probe.resolutionRemaining; before=probe.engine.snapshot; [probe.engine pause]; [probe advanceGameClock:2]; BOOL resolutionPause=resolution>0 && [before isEqual:probe.engine.snapshot] && probe.resolutionRemaining==resolution; [probe.engine resume];
    GameScene *refund=[self clockProbe]; [refund.engine setFixtureEnergy:@[@20,@20,@20,@20]]; [refund.engine activateSkill:GDColorWhite]; [self probeStartShot:refund]; GDEngine *cold=[[GDEngine alloc] initWithSnapshot:refund.engine.snapshot]; [cold resume]; BOOL wildRefund=cold.phase==GDPhaseReady && cold.wildRemaining==5 && cold.score==0;
    refund=[self clockProbe]; [refund.engine setFixtureEnergy:@[@20,@20,@20,@20]]; [refund.engine activateSkill:GDColorRed]; [self probeStartShot:refund]; cold=[[GDEngine alloc] initWithSnapshot:refund.engine.snapshot]; [cold resume]; BOOL blastRefund=cold.phase==GDPhaseReady && cold.energy[GDColorRed].integerValue==20 && !cold.blastArmed;
    for(NSString *key in preferenceKeys){ id saved=originalPreferences[key]; if(saved==NSNull.null) [NSUserDefaults.standardUserDefaults removeObjectForKey:key]; else [NSUserDefaults.standardUserDefaults setObject:saved forKey:key]; }
    NSLog(@"QA clock sixty120Jitter=%d shot=%d flightPause=%d resolutionPause=%d coldWildRefund=%d coldBlastRefund=%d elapsed=%.9f pressure=%.9f",equal,shot,flightPause,resolutionPause,wildRefund,blastRefund,[sixty[@"elapsed"] doubleValue],[sixty[@"pressure"] doubleValue]);
}
#endif
- (NSString *)snapshotKey { return self.engine.mode==GDGameModeLevel?@"GummyLevelRunSnapshot":@"GummyRunSnapshot"; }
- (BOOL)finished { return self.engine.phase==GDPhaseGameOver || self.engine.phase==GDPhaseWon; }
- (void)saveRun {
#if DEBUG
    NSArray *args=NSProcessInfo.processInfo.arguments;
    if(self.qaPresentationFixture || [args containsObject:@"-qa-music"] || [args containsObject:@"-qa-freeze-art"] || [args containsObject:@"-qa-blast-art"]) return;
#endif
    if([self finished]) [NSUserDefaults.standardUserDefaults removeObjectForKey:[self snapshotKey]];
    else [NSUserDefaults.standardUserDefaults setObject:self.engine.snapshot forKey:[self snapshotKey]];
    [NSUserDefaults.standardUserDefaults setObject:self.engine.diagnostics forKey:@"GummyLastDiagnostics"];
}
- (void)pauseGame {
    if(self.overlay || [self finished]) return;
    [self clearAim]; self.yellowArmed=NO; [self.engine cancelBlast]; [self.engine pause]; self.playfield.paused=YES;
    [GDAudioFeedback.sharedPlayer pauseMusic];
    [self saveRun];
    [NSUserDefaults.standardUserDefaults setObject:self.engine.diagnostics forKey:@"GummyLastDiagnostics"];
    [self showOverlay:NO];
}
- (void)backgroundPause:(NSNotification *)notification { [self pauseGame]; [self saveRun]; }
- (void)addOverlayButton:(NSString *)title name:(NSString *)name y:(CGFloat)y color:(UIColor *)color {
    CGSize size=CGSizeMake(512,96);
    SKNode *button=[GummyUI button:title size:size name:name color:color]; button.position=CGPointMake(600,y); [self.overlay addChild:button];
    self.overlayControls[name]=[NSValue valueWithCGRect:CGRectMake(button.position.x-size.width/2,y-size.height/2,size.width,size.height)];
}
- (void)showOverlay:(BOOL)gameOver {
    if(self.overlay) return;
    BOOL level=self.engine.mode==GDGameModeLevel, won=self.engine.phase==GDPhaseWon;
    [GummyUI setOverlayDimmed:YES]; [self clearAim]; self.overlay=[SKNode node]; self.overlay.zPosition=100; [self addChild:self.overlay]; self.overlayControls=[NSMutableDictionary dictionary];
    SKShapeNode *shade=[GummyUI panel:self.size fill:GummyUI.overlayShadeColor stroke:UIColor.clearColor radius:0]; shade.position=CGPointMake(600,340); [self.overlay addChild:shade];
    SKNode *card=[GummyUI surface:CGSizeMake(608,won?630:590) color:Cream() radius:34]; card.position=CGPointMake(600,340); [self.overlay addChild:card];
    SKLabelNode *title=[GummyUI label:gameOver?(won?@"LEVEL CLEAR":@"GAME OVER"):@"PAUSED" size:36 color:Ink()]; title.position=CGPointMake(600,won?610:574); [self.overlay addChild:title];
    NSString *mode=level?[NSString stringWithFormat:@"LEVEL %02ld",(long)self.engine.levelID]:@"ENDLESS";
#if DEBUG
    if(self.qaPresentationFixture){ SKLabelNode *fixture=[GummyUI label:@"QA FIXTURE" size:12 color:Ink()]; fixture.position=CGPointMake(600,won?640:600); [self.overlay addChild:fixture]; }
#endif
    SKLabelNode *modeLabel=[GummyUI label:mode size:18 color:Ink()]; modeLabel.position=CGPointMake(600,won?578:535); [self.overlay addChild:modeLabel];
    SKLabelNode *score=[GummyUI label:[NSString stringWithFormat:@"SCORE  %ld",(long)self.engine.score] size:28 color:Ink()]; score.position=CGPointMake(600,won?546:500); [self.overlay addChild:score];
    UIColor *blue=[UIColor colorWithRed:.64 green:.85 blue:1 alpha:1], *pink=[UIColor colorWithRed:.97 green:.75 blue:.82 alpha:1], *lilac=[UIColor colorWithRed:.85 green:.78 blue:.95 alpha:1], *gold=[UIColor colorWithRed:1 green:.87 blue:.64 alpha:1];
    if(!gameOver){
        [self addOverlayButton:@"Resume" name:@"resume" y:434 color:blue];
        [self addOverlayButton:@"Retry" name:@"retry" y:328 color:pink];
        [self addOverlayButton:@"Settings" name:@"settings" y:222 color:lilac];
        [self addOverlayButton:@"Home" name:@"home" y:116 color:gold];
    } else {
        if(won){
            for(NSInteger i=0;i<3;i++){ SKSpriteNode *star=[GummyUI star:44]; star.position=CGPointMake(536+i*64,506); BOOL earned=i<self.engine.stars; star.color=[UIColor colorWithRed:.59 green:.49 blue:.69 alpha:1]; star.colorBlendFactor=earned?0:.85; star.alpha=earned?1:.60; [self.overlay addChild:star]; if(earned){ star.xScale=star.yScale=.1; [star runAction:[SKAction sequence:@[[SKAction waitForDuration:i*.12],[SKAction scaleTo:1.16 duration:.15],[SKAction scaleTo:1 duration:.12]]]]; } }
            GDLevel *levelInfo=[GDLevelCatalog levelForID:self.engine.levelID];
            NSString *par=levelInfo.objective==GDObjectiveSurvive?[NSString stringWithFormat:@"3★: ≤%ld shots + ≥%ld points",(long)levelInfo.parShots,(long)levelInfo.parScore]:[NSString stringWithFormat:@"3★: ≤%ld shots + ≤%.0f seconds",(long)levelInfo.parShots,levelInfo.parTime];
            SKLabelNode *criteria=[GummyUI label:par size:17 color:Ink()]; criteria.position=CGPointMake(600,465); [self.overlay addChild:criteria];
            if([GDLevelCatalog levelForID:self.engine.levelID+1]) [self addOverlayButton:@"Next Level" name:@"nextLevel" y:404 color:blue];
            else [self addOverlayButton:@"All Levels" name:@"allLevels" y:404 color:blue];
            [self addOverlayButton:@"Replay" name:@"retry" y:298 color:pink]; [self addOverlayButton:@"Levels" name:@"levels" y:192 color:lilac]; [self addOverlayButton:@"Home" name:@"home" y:86 color:gold];
        } else if(level){
            SKLabelNode *goal=[GummyUI label:[NSString stringWithFormat:@"PROGRESS  %ld / %ld",(long)self.engine.objectiveCurrent,(long)self.engine.objectiveTarget] size:22 color:Ink()]; goal.position=CGPointMake(600,449); [self.overlay addChild:goal];
            [self addOverlayButton:@"Retry" name:@"retry" y:374 color:blue]; [self addOverlayButton:@"Levels" name:@"levels" y:260 color:lilac]; [self addOverlayButton:@"Home" name:@"home" y:146 color:gold];
        } else {
            GDRunRecords *records=[[GDRunRecords alloc] initWithDefaults:NSUserDefaults.standardUserDefaults]; NSInteger rank=[records rankForRunID:self.engine.runID];
            NSString *record=rank?[NSString stringWithFormat:@"LOCAL RANK  #%ld   ·   BEST %ld",(long)rank,(long)self.engine.bestScore]:[NSString stringWithFormat:@"BEST  %ld",(long)self.engine.bestScore];
            SKLabelNode *best=[GummyUI label:record size:22 color:Ink()]; best.position=CGPointMake(600,449); [self.overlay addChild:best];
            [self addOverlayButton:@"Retry" name:@"retry" y:374 color:blue]; [self addOverlayButton:@"Local Scores" name:@"scores" y:260 color:lilac]; [self addOverlayButton:@"Home" name:@"home" y:146 color:gold];
        }
        [GDSettings.sharedSettings playFeedback:won?GDFeedbackWin:GDFeedbackGameOver]; [self saveRun];
    }
}
- (void)goHome {
    [self clearAim]; [self.engine cancelBlast]; if(![self finished]) [self.engine pause]; self.playfield.paused=YES; [self saveRun]; [self.view presentScene:[FrontendScene homeScene]];
}
- (NSUInteger)newRunSeed {
#if DEBUG
    NSArray *args=NSProcessInfo.processInfo.arguments;
    if([args containsObject:@"-qa-ready"] || [args containsObject:@"-qa-failure"] || [args containsObject:@"-qa-new"] || [args containsObject:@"-qa-freeze-art"] || [args containsObject:@"-qa-blast-art"]) return 20260930;
#endif
    return ((NSUInteger)arc4random()<<16)^arc4random();
}
- (void)restart {
    [GummyUI setOverlayDimmed:NO];
    self.generation++; [self.playfield removeAllActions]; [self.effects removeAllChildren]; [self clearAim]; [self.overlay removeFromParent]; self.overlay=nil; self.playfield.paused=NO;
    NSInteger levelID=self.engine.mode==GDGameModeLevel?self.engine.levelID:0;
    self.engine=levelID?[[GDEngine alloc] initWithLevelID:levelID seed:[GDLevelCatalog levelForID:levelID].seed]:[[GDEngine alloc] initWithSeed:[self newRunSeed]];
    self.combo=0; self.musicDanger=NO; self.flightRemaining=self.resolutionRemaining=-1; self.displayedEnergy=[self.engine.energy copy];
    for(SKNode *node in self.launcherNodes){ [node removeAllActions]; node.xScale=node.yScale=1; }
    for(SKNode *node in self.skillCards){ [node removeAllActions]; node.xScale=node.yScale=1; }
    for(SKNode *node in [self.hud.children copy]) if([node.name isEqualToString:@"feedback"]) [node removeFromParent];
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-ready"]) [self.engine setFixtureEnergy:@[@20,@20,@20,@20]];
#endif
    self.yellowArmed=NO; self.renderedRevision=-1; self.lastTime=0; self.displayedCurrent=-99;
    for(SKNode *node in self.pieceNodes.allValues) [node removeFromParent]; [self.pieceNodes removeAllObjects];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self snapshotKey]]; [self syncBoard]; [self refreshHUD];
    [self refreshMusic];
    [GDAudioFeedback.sharedPlayer resumeMusic];
}
@end
