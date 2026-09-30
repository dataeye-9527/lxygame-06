#import "FrontendScene.h"
#import "GameScene.h"
#import "GummyUI.h"
#import "GDEngine.h"
#import "GDSettings.h"

static UIColor *MenuInk(void) { return [UIColor colorWithRed:.34 green:.26 blue:.43 alpha:1]; }
static UIColor *MenuCream(void) { return [UIColor colorWithRed:1 green:.93 blue:.87 alpha:1]; }
static UIColor *MenuBlue(void) { return [UIColor colorWithRed:.65 green:.86 blue:1 alpha:1]; }
@interface FrontendScene ()
@property(nonatomic,copy) NSString *page;
@property(nonatomic) SKScene *returnScene;
@property(nonatomic) NSMutableDictionary<NSString *,NSValue *> *controls;
@property(nonatomic) NSDictionary *runSnapshot;
@property(nonatomic) UITouch *activeTouch;
@property(nonatomic,copy) NSString *pressedControl;
@end
@implementation FrontendScene
+ (instancetype)homeScene { FrontendScene *s=[self sceneWithSize:CGSizeMake(1200,680)]; s.page=@"home"; s.scaleMode=SKSceneScaleModeAspectFit; return s; }
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
    else [self buildHelp];
}
- (void)buildHome {
    id snapshot=[NSUserDefaults.standardUserDefaults objectForKey:@"GummyRunSnapshot"];
    GDEngine *restored=[snapshot isKindOfClass:NSDictionary.class]?[[GDEngine alloc] initWithSnapshot:snapshot]:nil;
    self.runSnapshot=restored && restored.phase!=GDPhaseGameOver?snapshot:nil;
    SKNode *titleCard=[GummyUI surface:CGSizeMake(465,100) color:MenuCream() radius:40]; titleCard.position=CGPointMake(355,577); [self addChild:titleCard];
    [self text:@"GUMMY DROP" size:48 at:CGPointMake(355,578)];
    SKSpriteNode *hero=[GummyUI image:@"menu_hero" size:CGSizeMake(520,390)];
    if(hero){ hero.position=CGPointMake(350,340); [self addChild:hero]; }
    else { for(NSInteger i=0;i<4;i++){ SKNode *piece=[GummyUI piece:i diameter:120]; piece.position=CGPointMake(240+(i%2)*205,285+(i/2)*140); [self addChild:piece]; } }
    SKNode *best=[GummyUI surface:CGSizeMake(290,60) color:MenuCream() radius:28]; best.position=CGPointMake(355,116); [self addChild:best];
    [self text:[NSString stringWithFormat:@"BEST  %ld",(long)[NSUserDefaults.standardUserDefaults integerForKey:@"GDPrototypeBestScore"]] size:24 at:CGPointMake(355,117)];
    SKNode *card=[GummyUI surface:CGSizeMake(384,490) color:MenuCream() radius:36]; card.position=CGPointMake(869,345); [self addChild:card];
    [self text:@"ENDLESS" size:21 at:CGPointMake(869,548)];
    [self button:self.runSnapshot?@"New Game":@"Play" name:@"play" center:CGPointMake(869,463) size:CGSizeMake(292,72) color:MenuBlue()];
    if(self.runSnapshot) [self button:@"Resume" name:@"resume" center:CGPointMake(869,374) size:CGSizeMake(292,64) color:[UIColor colorWithRed:.87 green:.81 blue:.97 alpha:1]];
    else { for(NSInteger i=0;i<4;i++){ SKNode *piece=[GummyUI piece:i diameter:30]; piece.position=CGPointMake(797+i*48,374); [self addChild:piece]; } }
    [self button:@"Settings" name:@"settings" center:CGPointMake(869,285) size:CGSizeMake(292,64) color:[UIColor colorWithRed:.99 green:.80 blue:.85 alpha:1]];
    [self button:@"How to Play" name:@"help" center:CGPointMake(869,196) size:CGSizeMake(292,64) color:[UIColor colorWithRed:1 green:.87 blue:.61 alpha:1]];
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
    if([control isEqualToString:@"play"] || [control isEqualToString:@"resume"]){
        NSDictionary *snapshot=[control isEqualToString:@"resume"]?self.runSnapshot:nil;
        if(!snapshot) [NSUserDefaults.standardUserDefaults removeObjectForKey:@"GummyRunSnapshot"];
        GameScene *game=[[GameScene alloc] initWithSize:self.size runSnapshot:snapshot]; game.scaleMode=SKSceneScaleModeAspectFit; [self.view presentScene:game];
    } else if([control isEqualToString:@"settings"]) [self.view presentScene:[FrontendScene settingsSceneReturningTo:self]];
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
