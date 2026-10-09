#import "GDViewController.h"
#import <SpriteKit/SpriteKit.h>
#import "GameScene.h"
#import "FrontendScene.h"
#import "GummyUI.h"
#if DEBUG
#import "GDAudioFeedback.h"
#endif

@interface GDViewController ()
@property(nonatomic) SKView *gameView;
@property(nonatomic) NSArray<UIView *> *backgroundDimmers;
@end
@implementation GDViewController
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }
- (BOOL)shouldAutorotate { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (void)pauseForSystemInterruption {
    if([self.gameView.scene isKindOfClass:GameScene.class]) [(GameScene *)self.gameView.scene pauseForSystemInterruption];
}
- (void)setSceneActive:(BOOL)active { self.gameView.paused=!active; }
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self pauseForSystemInterruption];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect available=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);
    if(available.size.width<=0 || available.size.height<=0){ self.gameView.frame=CGRectZero; return; }
    CGFloat scale=MIN(available.size.width/1200.0,available.size.height/680.0);
    CGSize size=CGSizeMake(1200*scale,680*scale);
    self.gameView.frame=CGRectMake(CGRectGetMidX(available)-size.width/2,CGRectGetMidY(available)-size.height/2,size.width,size.height);
    CGRect bounds=self.view.bounds, content=self.gameView.frame;
    // These strips meet the SpriteKit shade without tinting its background twice.
    self.backgroundDimmers[0].frame=CGRectMake(CGRectGetMinX(bounds),CGRectGetMinY(bounds),bounds.size.width,CGRectGetMinY(content)-CGRectGetMinY(bounds));
    self.backgroundDimmers[1].frame=CGRectMake(CGRectGetMinX(bounds),CGRectGetMaxY(content),bounds.size.width,CGRectGetMaxY(bounds)-CGRectGetMaxY(content));
    self.backgroundDimmers[2].frame=CGRectMake(CGRectGetMinX(bounds),CGRectGetMinY(content),CGRectGetMinX(content)-CGRectGetMinX(bounds),content.size.height);
    self.backgroundDimmers[3].frame=CGRectMake(CGRectGetMaxX(content),CGRectGetMinY(content),CGRectGetMaxX(bounds)-CGRectGetMaxX(content),content.size.height);
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-lifecycle"]){
        NSAssert(fabs(content.size.width/content.size.height-1200.0/680.0)<.00001,@"Game canvas must keep its aspect ratio");
        NSAssert(CGRectContainsRect(CGRectInset(available,-.01,-.01),content),@"Game canvas must remain inside the safe area");
        NSLog(@"QA lifecycle layout bounds=%@ safe=%@ content=%@",NSStringFromCGRect(bounds),NSStringFromCGRect(available),NSStringFromCGRect(content));
    }
#endif
}
- (void)overlayDimChanged:(NSNotification *)notification {
    BOOL dimmed=[notification.userInfo[@"dimmed"] boolValue];
    for(UIView *strip in self.backgroundDimmers) strip.hidden=!dimmed;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    UIImageView *background=[[UIImageView alloc] initWithFrame:self.view.bounds];
    background.image=[UIImage imageNamed:@"home_background_v4"]; background.contentMode=UIViewContentModeScaleAspectFill;
    background.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [self.view addSubview:background];
    NSMutableArray *dimmers=[NSMutableArray array];
    for(NSInteger i=0;i<4;i++){ UIView *strip=[UIView new]; strip.backgroundColor=GummyUI.overlayShadeColor; strip.userInteractionEnabled=NO; strip.hidden=YES; [self.view addSubview:strip]; [dimmers addObject:strip]; }
    self.backgroundDimmers=dimmers;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(overlayDimChanged:) name:GummyUIOverlayDimDidChangeNotification object:nil];
    SKView *view = [[SKView alloc] initWithFrame:self.view.bounds];
    view.backgroundColor=UIColor.clearColor; view.opaque=NO; view.allowsTransparency=YES;
    self.gameView=view;
    view.ignoresSiblingOrder = NO;
    [self.view addSubview:view];
    SKScene *scene = [FrontendScene homeScene];
#if DEBUG
    NSArray *args=NSProcessInfo.processInfo.arguments;
    if([args containsObject:@"-qa-last-level"]) scene=[[GameScene alloc] initWithSize:CGSizeMake(1200,680) levelID:30];
    if([args containsObject:@"-qa-result"]) scene=[[GameScene alloc] initWithSize:CGSizeMake(1200,680) runSnapshot:nil];
    if([args containsObject:@"-qa-ready"] || [args containsObject:@"-qa-failure"] || [args containsObject:@"-qa-new"] || [args containsObject:@"-qa-music"] || [args containsObject:@"-qa-freeze-art"] || [args containsObject:@"-qa-blast-art"]) scene=[[GameScene alloc] initWithSize:CGSizeMake(1200,680) runSnapshot:nil];
#endif
    scene.scaleMode = SKSceneScaleModeAspectFit;
    [view presentScene:scene];
#if DEBUG
    if([NSProcessInfo.processInfo.arguments containsObject:@"-qa-audio"]) [GDAudioFeedback.sharedPlayer startQAPlaybackTour];
#endif
}
@end
