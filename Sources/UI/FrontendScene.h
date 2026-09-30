#import <SpriteKit/SpriteKit.h>
@interface FrontendScene : SKScene
+ (instancetype)homeScene;
+ (instancetype)settingsSceneReturningTo:(SKScene *)scene;
+ (instancetype)helpScene;
@end
