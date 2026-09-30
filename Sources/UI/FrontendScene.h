#import <SpriteKit/SpriteKit.h>
@interface FrontendScene : SKScene
+ (instancetype)homeScene;
+ (instancetype)levelsScene;
+ (instancetype)leaderboardScene;
+ (instancetype)settingsSceneReturningTo:(SKScene *)scene;
+ (instancetype)helpScene;
@end
