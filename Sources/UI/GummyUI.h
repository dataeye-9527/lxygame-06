#import <SpriteKit/SpriteKit.h>

FOUNDATION_EXPORT NSNotificationName const GummyUIOverlayDimDidChangeNotification;

@interface GummyUI : NSObject
+ (UIColor *)color:(NSInteger)index;
+ (SKNode *)piece:(NSInteger)index diameter:(CGFloat)diameter;
+ (SKShapeNode *)panel:(CGSize)size fill:(UIColor *)fill stroke:(UIColor *)stroke radius:(CGFloat)radius;
+ (SKLabelNode *)label:(NSString *)text size:(CGFloat)size color:(UIColor *)color;
+ (SKNode *)button:(NSString *)title size:(CGSize)size name:(NSString *)name color:(UIColor *)color;
+ (SKNode *)candyButton:(NSString *)title size:(CGSize)size name:(NSString *)name atlas:(NSString *)atlas row:(NSInteger)row icon:(NSString *)icon fontSize:(CGFloat)fontSize color:(UIColor *)color enabled:(BOOL)enabled;
+ (SKNode *)symbol:(NSString *)name size:(CGFloat)size color:(UIColor *)color;
+ (SKSpriteNode *)star:(CGFloat)size;
+ (SKNode *)surface:(CGSize)size color:(UIColor *)color radius:(CGFloat)radius;
+ (SKSpriteNode *)gradient:(CGSize)size top:(UIColor *)top bottom:(UIColor *)bottom;
+ (void)addBackgroundTo:(SKScene *)scene;
+ (UIColor *)overlayShadeColor;
+ (void)setOverlayDimmed:(BOOL)dimmed;
+ (SKSpriteNode *)image:(NSString *)name size:(CGSize)size;
@end
