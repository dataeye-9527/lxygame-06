#import "GummyUI.h"

NSNotificationName const GummyUIOverlayDimDidChangeNotification = @"GummyUIOverlayDimDidChange";

@implementation GummyUI
+ (SKSpriteNode *)image:(NSString *)name size:(CGSize)size {
    static NSMutableDictionary *textures; if(!textures) textures=[NSMutableDictionary dictionary];
    SKTexture *texture=textures[name];
    if(!texture){ NSString *path=[[NSBundle mainBundle] pathForResource:name ofType:@"png"]; if(!path) return nil;
        UIImage *image=[UIImage imageWithContentsOfFile:path]; if(!image) return nil;
        texture=[SKTexture textureWithImage:image]; texture.filteringMode=SKTextureFilteringLinear; textures[name]=texture; }
    return [SKSpriteNode spriteNodeWithTexture:texture size:size];
}
+ (void)addBackgroundTo:(SKScene *)scene {
    // The host view draws one continuous image behind the safe-area content.
    scene.backgroundColor=UIColor.clearColor;
}
+ (UIColor *)overlayShadeColor { return [UIColor colorWithRed:.18 green:.14 blue:.30 alpha:.66]; }
+ (void)setOverlayDimmed:(BOOL)dimmed {
    [NSNotificationCenter.defaultCenter postNotificationName:GummyUIOverlayDimDidChangeNotification object:nil userInfo:@{@"dimmed":@(dimmed)}];
}
+ (SKSpriteNode *)gradient:(CGSize)size top:(UIColor *)top bottom:(UIColor *)bottom {
    CGSize canvas=CGSizeMake(32,256); UIGraphicsBeginImageContextWithOptions(canvas,NO,1);
    CGContextRef context=UIGraphicsGetCurrentContext(); CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient=CGGradientCreateWithColors(space,(__bridge CFArrayRef)@[(__bridge id)top.CGColor,(__bridge id)bottom.CGColor],NULL);
    CGContextDrawLinearGradient(context,gradient,CGPointZero,CGPointMake(0,canvas.height),0);
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); CGGradientRelease(gradient); CGColorSpaceRelease(space);
    return [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImage:image] size:size];
}
+ (SKNode *)surface:(CGSize)size color:(UIColor *)color radius:(CGFloat)radius {
    SKNode *root=[SKNode node];
    SKShapeNode *shadow=[self panel:size fill:[UIColor colorWithRed:.34 green:.20 blue:.46 alpha:.20] stroke:UIColor.clearColor radius:radius]; shadow.position=CGPointMake(0,-6); [root addChild:shadow];
    SKShapeNode *rim=[self panel:size fill:color stroke:[UIColor colorWithWhite:1 alpha:.75] radius:radius]; rim.lineWidth=2.5; [root addChild:rim];
    CGFloat red=1,green=1,blue=1,alpha=1; [color getRed:&red green:&green blue:&blue alpha:&alpha];
    UIColor *light=[UIColor colorWithRed:red+(1-red)*.32 green:green+(1-green)*.32 blue:blue+(1-blue)*.32 alpha:alpha];
    UIColor *dark=[UIColor colorWithRed:red*.95 green:green*.95 blue:blue*.95 alpha:alpha];
    SKCropNode *body=[SKCropNode node]; body.maskNode=[self panel:CGSizeMake(size.width-5,size.height-5) fill:UIColor.whiteColor stroke:UIColor.clearColor radius:MAX(3,radius-2)];
    [body addChild:[self gradient:CGSizeMake(size.width-5,size.height-5) top:light bottom:dark]]; [root addChild:body];
    SKShapeNode *inset=[self panel:CGSizeMake(size.width-12,size.height-12) fill:[UIColor colorWithWhite:1 alpha:.10] stroke:[UIColor colorWithRed:.62 green:.40 blue:.53 alpha:.14] radius:MAX(4,radius-5)]; inset.position=CGPointMake(0,1); [root addChild:inset];
    CGMutablePathRef edge=CGPathCreateMutable(); CGPathMoveToPoint(edge,NULL,-size.width/2+radius,size.height/2-5); CGPathAddLineToPoint(edge,NULL,size.width/2-radius,size.height/2-5);
    SKShapeNode *gloss=[SKShapeNode shapeNodeWithPath:edge]; CGPathRelease(edge); gloss.strokeColor=[UIColor colorWithWhite:1 alpha:.60]; gloss.lineWidth=2; [root addChild:gloss]; return root;
}
+ (UIColor *)color:(NSInteger)index {
    switch (index) {
        case 0: return [UIColor colorWithRed:.08 green:.70 blue:1 alpha:1];
        case 1: return [UIColor colorWithRed:1 green:.29 blue:.38 alpha:1];
        case 2: return [UIColor colorWithRed:1 green:.78 blue:.08 alpha:1];
        default: return [UIColor colorWithRed:1 green:.95 blue:.87 alpha:1];
    }
}
+ (SKShapeNode *)panel:(CGSize)size fill:(UIColor *)fill stroke:(UIColor *)stroke radius:(CGFloat)radius {
    SKShapeNode *p=[SKShapeNode shapeNodeWithRectOfSize:size cornerRadius:radius];
    p.fillColor=fill; p.strokeColor=stroke; p.lineWidth=2; return p;
}
+ (SKLabelNode *)label:(NSString *)text size:(CGFloat)size color:(UIColor *)color {
    SKLabelNode *l=[SKLabelNode labelNodeWithFontNamed:@"AvenirNext-Heavy"];
    l.text=text; l.fontSize=size; l.fontColor=color; l.verticalAlignmentMode=SKLabelVerticalAlignmentModeCenter; l.horizontalAlignmentMode=SKLabelHorizontalAlignmentModeCenter; return l;
}
+ (SKNode *)piece:(NSInteger)index diameter:(CGFloat)diameter {
    NSArray *names=@[@"gummy_blue",@"gummy_red",@"gummy_yellow",@"gummy_white"];
    SKSpriteNode *sprite=[self image:names[MAX(0,MIN(3,index))] size:CGSizeMake(diameter/0.90,diameter/0.90)];
    if(sprite) return sprite;
    SKNode *root=[SKNode node];
    SKShapeNode *shadow=[SKShapeNode shapeNodeWithCircleOfRadius:diameter/2]; shadow.fillColor=[UIColor colorWithWhite:0 alpha:.18]; shadow.strokeColor=UIColor.clearColor; shadow.position=CGPointMake(0,-2); [root addChild:shadow];
    SKShapeNode *disc=[SKShapeNode shapeNodeWithCircleOfRadius:diameter/2]; disc.fillColor=[self color:index]; disc.strokeColor=[UIColor colorWithWhite:1 alpha:.65]; disc.lineWidth=1.6; [root addChild:disc];
    SKShapeNode *shine=[SKShapeNode shapeNodeWithEllipseOfSize:CGSizeMake(diameter*.48,diameter*.17)]; shine.fillColor=[UIColor colorWithWhite:1 alpha:.36]; shine.strokeColor=UIColor.clearColor; shine.position=CGPointMake(-diameter*.09,diameter*.25); shine.zRotation=.25; [root addChild:shine];
    NSArray *symbols=@[@"❄",@"✳",@"⌄",@"○"];
    SKLabelNode *mark=[self label:symbols[MAX(0,MIN(3,index))] size:diameter*.55 color:[UIColor colorWithWhite:1 alpha:.95]]; mark.position=CGPointMake(0,-1); [root addChild:mark];
    return root;
}
 + (SKNode *)button:(NSString *)title size:(CGSize)size name:(NSString *)name color:(UIColor *)color {
    SKNode *root=[self surface:size color:color radius:size.height/2]; root.name=name;
    SKShapeNode *gloss=[self panel:CGSizeMake(size.width-20,size.height*.34) fill:[UIColor colorWithWhite:1 alpha:.16] stroke:UIColor.clearColor radius:size.height*.17]; gloss.position=CGPointMake(0,size.height*.20); [root addChild:gloss];
    SKLabelNode *label=[self label:title size:MIN(23,size.height*.40) color:[UIColor colorWithRed:.34 green:.23 blue:.43 alpha:1]]; [root addChild:label]; return root;
}
@end
