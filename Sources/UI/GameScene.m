#import "GameScene.h"
#import "GummyUI.h"
#import "GDEngine.h"
#import "FrontendScene.h"
#import "GDSettings.h"
#import <UIKit/UIKit.h>

static UIColor *Ink(void) { return [UIColor colorWithRed:.34 green:.26 blue:.43 alpha:1]; }
static UIColor *Cream(void) { return [UIColor colorWithRed:1 green:.92 blue:.85 alpha:1]; }
static CGPoint ScenePoint(CGPoint p) { return CGPointMake(174+p.x,603-p.y); }
static CGPoint BoardPoint(CGPoint p) { return CGPointMake(p.x-174,603-p.y); }

@interface GameScene ()
@property(nonatomic) GDEngine *engine;
@property(nonatomic) NSDictionary *initialRunSnapshot;
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
@property(nonatomic) BOOL aiming, yellowArmed, renderedGameOver;
@property(nonatomic) NSTimeInterval lastTime;
@property(nonatomic) NSInteger renderedRevision, displayedNext, displayedHeld, displayedCurrent, generation;
@end

@implementation GameScene
- (instancetype)initWithSize:(CGSize)size runSnapshot:(NSDictionary *)snapshot {
    if((self=[super initWithSize:size])) self.initialRunSnapshot=snapshot; return self;
}
- (void)didMoveToView:(SKView *)view {
    [GummyUI setOverlayDimmed:self.overlay!=nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundPause:) name:UIApplicationWillResignActiveNotification object:nil];
    if(self.engine){ self.lastTime=0; [self refreshHUD]; return; }
    self.anchorPoint=CGPointZero;
    self.pieceNodes=[NSMutableDictionary dictionary]; self.skillCards=[NSMutableArray array]; self.launcherNodes=[NSMutableArray array]; self.energyFills=[NSMutableArray array]; self.energyLabels=[NSMutableArray array];
    self.displayedNext=self.displayedHeld=self.displayedCurrent=-99; self.renderedRevision=-1;
    NSArray *args=NSProcessInfo.processInfo.arguments;
    NSDictionary *saved=self.initialRunSnapshot; self.initialRunSnapshot=nil;
    NSUInteger seed=[self newRunSeed];
    self.engine=saved ? [[GDEngine alloc] initWithSnapshot:saved] : [[GDEngine alloc] initWithSeed:seed];
    if(!self.engine) self.engine=[[GDEngine alloc] initWithSeed:seed];
#if DEBUG
    if(!saved && [args containsObject:@"-qa-ready"]) [self.engine setFixtureEnergy:@[@20,@20,@20,@20]];
    if(!saved && [args containsObject:@"-qa-failure"]){
        NSMutableArray *cells=[self.engine.cells mutableCopy];
        for(NSInteger row=6;row<12;row++) [cells addObject:[GDCell row:row column:8 color:GDColorRed]];
        [self.engine loadFixture:cells phase:0 current:GDColorBlue next:GDColorYellow];
    }
#endif
    [self buildLayout]; [self syncBoard]; [self refreshHUD];
    if(self.engine.phase==GDPhasePaused) [self.engine resume];
#if DEBUG
    if(saved && [args containsObject:@"-qa-feedback"]){ NSData *data=[NSJSONSerialization dataWithJSONObject:self.engine.snapshot options:0 error:nil]; NSLog(@"QA restored snapshot=%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]); }
#endif
}
- (void)willMoveFromView:(SKView *)view { [GummyUI setOverlayDimmed:NO]; [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)buildLayout {
    [GummyUI addBackgroundTo:self];
    SKNode *boardFrame=[GummyUI surface:CGSizeMake(856,582) color:[UIColor colorWithRed:.73 green:.62 blue:.82 alpha:1] radius:25]; boardFrame.position=CGPointMake(588,326); [self addChild:boardFrame];
    SKShapeNode *inner=[GummyUI panel:CGSizeMake(828,555) fill:[UIColor colorWithRed:.25 green:.24 blue:.43 alpha:1] stroke:[UIColor colorWithRed:.48 green:.39 blue:.60 alpha:1] radius:15]; inner.position=CGPointMake(588,324); inner.lineWidth=2; [self addChild:inner];
    SKCropNode *clip=[SKCropNode node]; clip.position=inner.position; clip.maskNode=[GummyUI panel:CGSizeMake(824,551) fill:UIColor.whiteColor stroke:UIColor.clearColor radius:13];
    SKSpriteNode *gradient=[GummyUI gradient:CGSizeMake(824,551) top:[UIColor colorWithRed:.25 green:.25 blue:.43 alpha:1] bottom:[UIColor colorWithRed:.40 green:.35 blue:.58 alpha:1]]; [clip addChild:gradient]; [self addChild:clip];
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
    SKNode *timer=[GummyUI surface:CGSizeMake(146,54) color:[UIColor colorWithRed:.94 green:.42 blue:.59 alpha:1] radius:25]; timer.position=CGPointMake(604,645); [self.hud addChild:timer];
    self.timerTitle=[GummyUI label:@"NEW ROW" size:13 color:UIColor.whiteColor]; self.timerTitle.position=CGPointMake(604,658); [self.hud addChild:self.timerTitle];
    self.timerLabel=[GummyUI label:@"00:12" size:25 color:UIColor.whiteColor]; self.timerLabel.position=CGPointMake(604,636); [self.hud addChild:self.timerLabel];
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
    for(NSInteger i=0;i<2;i++){ SKNode *slot=[GummyUI panel:CGSizeMake(109,108) fill:[UIColor colorWithRed:.85 green:.72 blue:.73 alpha:1] stroke:[UIColor colorWithRed:.94 green:.79 blue:.76 alpha:1] radius:21]; slot.position=CGPointMake(1110,i?317:477); slot.name=i?@"hold":@"next"; [self.hud addChild:slot]; }
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
    self.timerTitle.text=frozen?@"FROZEN":@"NEW ROW";
    NSTimeInterval remaining=frozen?self.engine.freezeRemaining:self.engine.pressureRemaining;
    NSInteger seconds=(NSInteger)ceil(MAX(0,remaining)); self.timerLabel.text=[NSString stringWithFormat:@"%02ld:%02ld",(long)(seconds/60),(long)(seconds%60)];
    self.timerLabel.fontColor=frozen?[UIColor colorWithRed:.73 green:.96 blue:1 alpha:1]:UIColor.whiteColor;
    for(NSInteger i=0;i<4;i++){
        NSInteger energy=self.engine.energy[i].integerValue; CGFloat amount=MAX(0,MIN(1,(CGFloat)energy/self.engine.energyThreshold));
        CGPathRef path=CGPathCreateWithRoundedRect(CGRectMake(0,-5.5,MAX(1,106*amount),11),5,5,NULL); self.energyFills[i].path=path; CGPathRelease(path);
        self.energyLabels[i].text=energy>=self.engine.energyThreshold?@"READY":[NSString stringWithFormat:@"%ld/%ld",(long)energy,(long)self.engine.energyThreshold];
        self.energyLabels[i].fontColor=Ink();
        SKNode *ready=[self.skillCards[i] childNodeWithName:@"readyOutline"];
        if(energy>=self.engine.energyThreshold && !ready){ SKShapeNode *outline=[GummyUI panel:CGSizeMake(126,134) fill:UIColor.clearColor stroke:[GummyUI color:i] radius:19]; outline.name=@"readyOutline"; outline.lineWidth=3; outline.zPosition=3; [self.skillCards[i] addChild:outline]; }
        else if(energy<self.engine.energyThreshold) [ready removeFromParent];
        self.skillCards[i].alpha=self.engine.phase==GDPhaseReady?1:.7;
    }
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
    if(![control isEqualToString:@"overlay"] && ![control isEqualToString:@"next"]) [GDSettings.sharedSettings playFeedback:GDFeedbackTap];
    if([control isEqualToString:@"pause"]){ [self pauseGame]; return; }
    if([control isEqualToString:@"resume"]){ [self.overlay removeFromParent]; self.overlay=nil; [GummyUI setOverlayDimmed:NO]; self.playfield.paused=NO; [self.engine resume]; self.lastTime=0; return; }
    if([control isEqualToString:@"retry"]){ [self restart]; return; }
    if([control isEqualToString:@"home"]){ [self goHome]; return; }
    if([control isEqualToString:@"settings"]){ [self.view presentScene:[FrontendScene settingsSceneReturningTo:self]]; return; }
    if(self.engine.phase!=GDPhaseReady) return;
    [self clearAim];
    if([control hasPrefix:@"launcher"]){ [self.engine selectLauncher:[[control substringFromIndex:8] integerValue]]; self.yellowArmed=NO; }
    else if([control isEqualToString:@"hold"]){ [self.engine hold]; self.yellowArmed=NO; }
    else if([control hasPrefix:@"skill"]){
        NSInteger i=[[control substringFromIndex:5] integerValue];
        if(i==GDColorYellow){
            if(self.yellowArmed){ self.yellowArmed=NO; GDEvent *event=[self.engine activateYellow]; if(event){ [GDSettings.sharedSettings playFeedback:GDFeedbackSkill]; [self animateEvent:event]; } }
            else if(self.engine.energy[GDColorYellow].integerValue>=self.engine.energyThreshold){ self.yellowArmed=YES; [self highlightCells:[self.engine yellowTargets] color:[GummyUI color:GDColorYellow]]; }
        } else { self.yellowArmed=NO; if([self.engine activateSkill:i]) [GDSettings.sharedSettings playFeedback:GDFeedbackSkill]; }
    }
    [self refreshHUD];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch=touches.anyObject; CGPoint p=[touch locationInNode:self]; NSString *control=[self controlAt:p];
    if([control hasPrefix:@"launcher"] && self.engine.phase==GDPhaseReady){
        [self handleControl:control]; self.aimTouch=touch; return;
    }
    if(control){ [self handleControl:control]; return; }
    if(self.engine.phase!=GDPhaseReady || self.aimTouch || p.x<174 || p.x>1002 || p.y<153 || p.y>607) return;
    self.yellowArmed=NO; self.aimTouch=touch; self.aiming=YES; [self updateAim:p];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(self.aimTouch && [touches containsObject:self.aimTouch]){ CGPoint p=[self.aimTouch locationInNode:self]; self.aiming=YES; [self updateAim:p]; }
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(!self.aimTouch || ![touches containsObject:self.aimTouch]) return;
    CGPoint p=[self.aimTouch locationInNode:self]; GDShot *shot=self.preview;
    BOOL cancel=p.y<153 || p.x<174 || p.x>1002 || [self controlAt:p]!=nil;
    [self clearAim];
    if(!cancel && shot.valid && [self.engine beginShot:shot]) [self flyShot:shot];
    else if(self.engine.blastArmed) [self.engine cancelBlast];
    [self refreshHUD];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self clearAim]; [self.engine cancelBlast]; [self refreshHUD]; }
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
        CGPoint p=ScenePoint([self.engine centerOfCell:self.preview.hitCell]); SKShapeNode *blast=[SKShapeNode shapeNodeWithCircleOfRadius:65]; blast.position=p; blast.strokeColor=[GummyUI color:GDColorRed]; blast.fillColor=[[GummyUI color:GDColorRed] colorWithAlphaComponent:.14]; blast.lineWidth=2; [self.aimLayer addChild:blast]; self.statusLabel.text=@"BLAST";
    } else self.statusLabel.text=@"Drag up to aim  ·  Release below board to cancel";
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-feedback"]) NSLog(@"QA aim guide enabled=1 nodes=%lu valid=%d",(unsigned long)self.aimLayer.children.count,self.preview.valid);
#endif
}
- (void)highlightCells:(NSArray<GDCell *> *)cells color:(UIColor *)color {
    for(GDCell *cell in cells){ SKShapeNode *ring=[SKShapeNode shapeNodeWithCircleOfRadius:24]; ring.position=ScenePoint([self.engine centerOfCell:cell]); ring.strokeColor=color; ring.fillColor=[color colorWithAlphaComponent:.12]; ring.lineWidth=2.5; [self.aimLayer addChild:ring]; }
}
- (void)flyShot:(GDShot *)shot {
    [GDSettings.sharedSettings playFeedback:GDFeedbackShot];
    SKNode *projectile=[GummyUI piece:shot.blast?GDColorRed:self.engine.currentColor diameter:45]; projectile.position=ScenePoint(shot.points.firstObject.CGPointValue); [self.effects addChild:projectile];
    NSMutableArray *actions=[NSMutableArray array];
    for(NSInteger i=1;i<shot.points.count;i++){ CGPoint a=shot.points[i-1].CGPointValue,b=shot.points[i].CGPointValue; NSTimeInterval duration=hypot(b.x-a.x,b.y-a.y)/1250.; [actions addObject:[SKAction moveTo:ScenePoint(b) duration:duration]]; }
    NSInteger generation=self.generation;
    __weak typeof(self) weakSelf=self;
    [actions addObject:[SKAction runBlock:^{ [projectile removeFromParent]; GameScene *scene=weakSelf; if(!scene || scene.generation!=generation) return; GDEvent *event=[scene.engine resolveShot]; if(event) [scene animateEvent:event]; }]];
    [projectile runAction:[SKAction sequence:actions]];
}
- (void)animateEvent:(GDEvent *)event {
    if(event.removed.count || event.fallen.count) [GDSettings.sharedSettings playFeedback:GDFeedbackMatch];
    [self clearAim]; self.yellowArmed=NO;
    for(GDCell *cell in event.removed){ SKNode *node=self.pieceNodes[cell.key]; if(!node) continue; [self.pieceNodes removeObjectForKey:cell.key]; CGPoint position=node.position; [node removeFromParent]; [self.effects addChild:node]; node.position=position;
        [node runAction:[SKAction sequence:@[[SKAction scaleTo:1.15 duration:.07],[SKAction group:@[[SKAction scaleTo:.15 duration:.20],[SKAction fadeOutWithDuration:.20]]],[SKAction removeFromParent]]]];
        for(NSInteger i=0;i<4;i++){ SKShapeNode *crumb=[SKShapeNode shapeNodeWithCircleOfRadius:2.5]; crumb.fillColor=[GummyUI color:cell.color]; crumb.strokeColor=UIColor.clearColor; crumb.position=position; [self.effects addChild:crumb]; CGFloat a=(i*1.57)+.4; [crumb runAction:[SKAction sequence:@[[SKAction group:@[[SKAction moveByX:cos(a)*28 y:sin(a)*28 duration:.22],[SKAction fadeOutWithDuration:.22]]],[SKAction removeFromParent]]]]; }
    }
    for(GDCell *cell in event.fallen){ SKNode *node=self.pieceNodes[cell.key]; if(!node) continue; [self.pieceNodes removeObjectForKey:cell.key]; CGPoint position=node.position; [node removeFromParent]; [self.effects addChild:node]; node.position=position; [node runAction:[SKAction sequence:@[[SKAction group:@[[SKAction moveByX:(cell.column%3-1)*15 y:-115 duration:.38],[SKAction rotateByAngle:(cell.column%2?.5:-.5) duration:.38],[SKAction fadeOutWithDuration:.38]]],[SKAction removeFromParent]]]]; }
    if(event.pushed){
        for(SKNode *node in self.pieceNodes.allValues) [node runAction:[SKAction moveByX:0 y:-self.engine.radius*sqrt(3) duration:.20]];
        self.renderedRevision=-1;
    } else { [self syncBoard]; }
    if(event.points>0){ SKLabelNode *points=[GummyUI label:[NSString stringWithFormat:@"+%ld",(long)event.points] size:27 color:Cream()]; points.position=CGPointMake(588,355); [self.effects addChild:points]; [points runAction:[SKAction sequence:@[[SKAction group:@[[SKAction moveByX:0 y:44 duration:.6],[SKAction fadeOutWithDuration:.6]]],[SKAction removeFromParent]]]]; }
    [self refreshHUD];
    NSInteger generation=self.generation; __weak typeof(self) weakSelf=self;
    [self.playfield runAction:[SKAction sequence:@[[SKAction waitForDuration:.38],[SKAction runBlock:^{ GameScene *scene=weakSelf; if(!scene || scene.generation!=generation) return; [scene syncBoard]; GDEvent *next=[scene.engine finishResolution]; if(next) [scene animateEvent:next]; else { [scene refreshHUD]; if(scene.engine.phase==GDPhaseGameOver) [scene showOverlay:YES]; } }]]] withKey:@"resolution"];
}
- (void)update:(NSTimeInterval)currentTime {
    NSTimeInterval delta=self.lastTime>0?MIN(.25,MAX(0,currentTime-self.lastTime)):0; self.lastTime=currentTime;
    GDEvent *event=[self.engine advanceTime:delta]; if(event){ [self clearAim]; [self animateEvent:event]; }
    [self refreshHUD];
    if(self.engine.phase==GDPhaseGameOver && !self.overlay) [self showOverlay:YES];
}
- (void)pauseGame {
    if(self.overlay || self.engine.phase==GDPhaseGameOver) return;
    [self clearAim]; self.yellowArmed=NO; [self.engine cancelBlast]; [self.engine pause]; self.playfield.paused=YES;
    [NSUserDefaults.standardUserDefaults setObject:self.engine.snapshot forKey:@"GummyRunSnapshot"];
    [NSUserDefaults.standardUserDefaults setObject:self.engine.diagnostics forKey:@"GummyLastDiagnostics"];
    [self showOverlay:NO];
}
- (void)backgroundPause:(NSNotification *)notification {
    [self pauseGame];
    if(self.engine.phase!=GDPhaseGameOver) [[NSUserDefaults standardUserDefaults] setObject:self.engine.snapshot forKey:@"GummyRunSnapshot"];
    else [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"GummyRunSnapshot"];
    [[NSUserDefaults standardUserDefaults] setObject:self.engine.diagnostics forKey:@"GummyLastDiagnostics"];
}
- (void)addOverlayButton:(NSString *)title name:(NSString *)name y:(CGFloat)y color:(UIColor *)color {
    CGSize size=CGSizeMake(286,57); SKNode *button=[GummyUI button:title size:size name:name color:color]; button.position=CGPointMake(600,y); [self.overlay addChild:button]; self.overlayControls[name]=[NSValue valueWithCGRect:CGRectMake(457,y-28.5,286,57)];
}
- (void)showOverlay:(BOOL)gameOver {
    if(self.overlay) return;
    [GummyUI setOverlayDimmed:YES];
    [self clearAim]; self.overlay=[SKNode node]; self.overlay.zPosition=100; [self addChild:self.overlay]; self.overlayControls=[NSMutableDictionary dictionary];
    SKShapeNode *shade=[GummyUI panel:self.size fill:GummyUI.overlayShadeColor stroke:UIColor.clearColor radius:0]; shade.position=CGPointMake(600,340); [self.overlay addChild:shade];
    SKNode *card=[GummyUI surface:CGSizeMake(424,gameOver?390:486) color:Cream() radius:34]; card.position=CGPointMake(600,340); [self.overlay addChild:card];
    SKLabelNode *title=[GummyUI label:gameOver?@"GAME OVER":@"PAUSED" size:35 color:Ink()]; title.position=CGPointMake(600,gameOver?487:529); [self.overlay addChild:title];
    SKLabelNode *score=[GummyUI label:[NSString stringWithFormat:@"SCORE  %ld",(long)self.engine.score] size:24 color:Ink()]; score.position=CGPointMake(600,gameOver?433:480); [self.overlay addChild:score];
    UIColor *blue=[UIColor colorWithRed:.64 green:.85 blue:1 alpha:1]; UIColor *pink=[UIColor colorWithRed:.97 green:.75 blue:.82 alpha:1]; UIColor *lilac=[UIColor colorWithRed:.85 green:.78 blue:.95 alpha:1];
    if(!gameOver){
        [self addOverlayButton:@"Resume" name:@"resume" y:407 color:blue];
        [self addOverlayButton:@"Retry" name:@"retry" y:334 color:pink];
        [self addOverlayButton:@"Settings" name:@"settings" y:261 color:lilac];
        [self addOverlayButton:@"Home" name:@"home" y:188 color:[UIColor colorWithRed:1 green:.87 blue:.64 alpha:1]];
    } else {
        SKLabelNode *best=[GummyUI label:[NSString stringWithFormat:@"BEST  %ld",(long)self.engine.bestScore] size:19 color:Ink()]; best.position=CGPointMake(600,393); [self.overlay addChild:best];
        [self addOverlayButton:@"Retry" name:@"retry" y:320 color:blue]; [self addOverlayButton:@"Home" name:@"home" y:242 color:pink];
        [GDSettings.sharedSettings playFeedback:GDFeedbackGameOver]; [NSUserDefaults.standardUserDefaults removeObjectForKey:@"GummyRunSnapshot"]; [NSUserDefaults.standardUserDefaults setObject:self.engine.diagnostics forKey:@"GummyLastDiagnostics"];
    }
}
- (void)goHome {
    [self clearAim]; [self.engine cancelBlast]; [self.engine pause]; self.playfield.paused=YES;
    if(self.engine.phase!=GDPhaseGameOver) [NSUserDefaults.standardUserDefaults setObject:self.engine.snapshot forKey:@"GummyRunSnapshot"];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:@"GummyRunSnapshot"];
    [NSUserDefaults.standardUserDefaults setObject:self.engine.diagnostics forKey:@"GummyLastDiagnostics"];
    [self.view presentScene:[FrontendScene homeScene]];
}
- (NSUInteger)newRunSeed {
#if DEBUG
    NSArray *args=NSProcessInfo.processInfo.arguments;
    if([args containsObject:@"-qa-ready"] || [args containsObject:@"-qa-failure"] || [args containsObject:@"-qa-new"]) return 20260930;
#endif
    return ((NSUInteger)arc4random()<<16)^arc4random();
}
- (void)restart {
    [GummyUI setOverlayDimmed:NO];
    self.generation++; [self.playfield removeAllActions]; [self.effects removeAllChildren]; [self clearAim]; [self.overlay removeFromParent]; self.overlay=nil; self.playfield.paused=NO;
    self.engine=[[GDEngine alloc] initWithSeed:[self newRunSeed]];
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-ready"]) [self.engine setFixtureEnergy:@[@20,@20,@20,@20]];
#endif
    self.yellowArmed=NO; self.renderedRevision=-1; self.lastTime=0; self.displayedCurrent=-99;
    for(SKNode *node in self.pieceNodes.allValues) [node removeFromParent]; [self.pieceNodes removeAllObjects];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"GummyRunSnapshot"]; [self syncBoard]; [self refreshHUD];
}
@end
