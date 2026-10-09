#import "SceneDelegate.h"
#import "GDViewController.h"
#import "GDAudioFeedback.h"

@implementation SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if(![scene isKindOfClass:UIWindowScene.class]) return;
    self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController=[GDViewController new];
    [self.window makeKeyAndVisible];
}
- (void)sceneDidBecomeActive:(UIScene *)scene {
    [(GDViewController *)self.window.rootViewController setSceneActive:YES];
    [GDAudioFeedback.sharedPlayer setSceneActive:YES];
}
- (void)sceneWillResignActive:(UIScene *)scene {
    [(GDViewController *)self.window.rootViewController pauseForSystemInterruption];
    [(GDViewController *)self.window.rootViewController setSceneActive:NO];
    [GDAudioFeedback.sharedPlayer setSceneActive:NO];
}
- (void)sceneDidEnterBackground:(UIScene *)scene {
    [self sceneWillResignActive:scene];
}
- (void)sceneDidDisconnect:(UIScene *)scene {
    [self sceneWillResignActive:scene];
    self.window=nil;
}
@end
