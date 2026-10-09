#import <SpriteKit/SpriteKit.h>

@interface GameScene : SKScene
- (instancetype)initWithSize:(CGSize)size levelID:(NSInteger)levelID;
- (instancetype)initWithSize:(CGSize)size runSnapshot:(NSDictionary *)snapshot;
- (void)pauseForSystemInterruption;
@end
