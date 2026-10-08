#import "GummyUI.h"
#import <CoreText/CoreText.h>

NSNotificationName const GummyUIOverlayDimDidChangeNotification = @"GummyUIOverlayDimDidChange";

// Keep dynamic SpriteKit labels and accessibility text, but center their visible glyphs.
@interface GDCandyLabel : SKLabelNode
@property(nonatomic) UIColor *inkColor;
@end
@implementation GDCandyLabel
- (void)setText:(NSString *)text { if([self.text isEqualToString:text]) return; [super setText:text]; [self redrawInk]; }
- (void)setFontSize:(CGFloat)size { if(self.fontSize==size) return; [super setFontSize:size]; [self redrawInk]; }
- (void)setFontName:(NSString *)name { if([self.fontName isEqualToString:name]) return; [super setFontName:name]; [self redrawInk]; }
- (UIColor *)fontColor { return self.inkColor?:[super fontColor]; }
- (void)setFontColor:(UIColor *)color { if([self.inkColor isEqual:color]) return; self.inkColor=color; [super setFontColor:UIColor.clearColor]; [self redrawInk]; }
- (void)setHorizontalAlignmentMode:(SKLabelHorizontalAlignmentMode)mode { [super setHorizontalAlignmentMode:mode]; [self redrawInk]; }
- (void)redrawInk {
    if(!self.text.length || self.fontSize<=0){ [self childNodeWithName:@"textFace"].hidden=YES; [self childNodeWithName:@"textEmboss"].hidden=YES; self.accessibilityLabel=self.text?:@""; return; }
    UIFont *font=[UIFont fontWithName:self.fontName?:@"AvenirNext-Heavy" size:self.fontSize]?:[UIFont systemFontOfSize:self.fontSize weight:UIFontWeightHeavy];
    UIColor *color=self.inkColor?:[UIColor colorWithRed:.35 green:.14 blue:.48 alpha:1];
    NSAttributedString *run=[[NSAttributedString alloc] initWithString:self.text attributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:color}];
    CTLineRef line=CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)run);
    CGRect ink=CTLineGetImageBounds(line,NULL); CGSize canvas=CGSizeMake(ceil(ink.size.width)+2,ceil(ink.size.height)+2);
    UIGraphicsBeginImageContextWithOptions(canvas,NO,2); CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context,0,canvas.height); CGContextScaleCTM(context,1,-1); CGContextSetTextMatrix(context,CGAffineTransformIdentity);
    CGContextSetTextPosition(context,1-ink.origin.x,1-ink.origin.y); CTLineDraw(line,context);
    UIImage *rendered=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); CFRelease(line);
    SKTexture *texture=[SKTexture textureWithImage:rendered]; texture.filteringMode=SKTextureFilteringLinear;
    SKSpriteNode *face=(SKSpriteNode *)[self childNodeWithName:@"textFace"], *emboss=(SKSpriteNode *)[self childNodeWithName:@"textEmboss"];
    if(!face){ face=[SKSpriteNode node]; face.name=@"textFace"; [self addChild:face]; }
    if(!emboss){ emboss=[SKSpriteNode node]; emboss.name=@"textEmboss"; emboss.zPosition=-1; [self addChild:emboss]; }
    CGFloat x=self.horizontalAlignmentMode==SKLabelHorizontalAlignmentModeLeft?ink.size.width/2:(self.horizontalAlignmentMode==SKLabelHorizontalAlignmentModeRight?-ink.size.width/2:0);
    face.texture=emboss.texture=texture; face.size=emboss.size=canvas; face.position=CGPointMake(x,0); emboss.position=CGPointMake(x,-1.2);
    emboss.color=UIColor.whiteColor; emboss.colorBlendFactor=1; emboss.alpha=.75; face.hidden=emboss.hidden=NO;
    self.accessibilityLabel=self.text;
}
@end

static UIImage *TrimmedSymbol(UIImage *image) {
    CGImageRef source=image.CGImage; size_t width=CGImageGetWidth(source),height=CGImageGetHeight(source);
    NSMutableData *pixels=[NSMutableData dataWithLength:width*height*4]; CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(pixels.mutableBytes,width,height,8,width*4,space,(CGBitmapInfo)kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGContextDrawImage(context,CGRectMake(0,0,width,height),source); const uint8_t *bytes=pixels.bytes;
    size_t left=width,right=0,top=height,bottom=0;
    for(size_t y=0;y<height;y++) for(size_t x=0;x<width;x++) if(bytes[(y*width+x)*4+3]>1){ left=MIN(left,x); right=MAX(right,x); top=MIN(top,y); bottom=MAX(bottom,y); }
    CGImageRef rendered=CGBitmapContextCreateImage(context), cropped=CGImageCreateWithImageInRect(rendered,CGRectMake(left,top,right-left+1,bottom-top+1));
    UIImage *result=[UIImage imageWithCGImage:cropped scale:image.scale orientation:UIImageOrientationUp];
    CGImageRelease(cropped); CGImageRelease(rendered); CGContextRelease(context); CGColorSpaceRelease(space); return result;
}

@implementation GummyUI
+ (SKSpriteNode *)image:(NSString *)name size:(CGSize)size {
    static NSMutableDictionary *textures; if(!textures) textures=[NSMutableDictionary dictionary];
    SKTexture *texture=textures[name];
    if(!texture){ NSString *path=[[NSBundle mainBundle] pathForResource:name ofType:@"png"];
        UIImage *image=path?[UIImage imageWithContentsOfFile:path]:[UIImage imageNamed:name]; if(!image) return nil;
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
    SKCropNode *root=[SKCropNode node]; root.maskNode=[self panel:size fill:UIColor.whiteColor stroke:UIColor.clearColor radius:radius];
    // Generated gloss retains its alpha; an opaque cream face keeps content readable.
    [root addChild:[self panel:size fill:[UIColor colorWithRed:1 green:.93 blue:.87 alpha:1] stroke:UIColor.clearColor radius:radius]];
    SKTexture *texture=[self image:@"candy_panel_v4" size:CGSizeMake(1,1)].texture;
    CGFloat cap=MIN(radius*1.5,MIN(size.width,size.height)/2);
    CGFloat source[]={0,.18,.82,1}, widths[]={cap,MAX(0,size.width-2*cap),cap}, heights[]={cap,MAX(0,size.height-2*cap),cap};
    CGFloat y=-size.height/2;
    for(NSInteger row=0;row<3;row++){
        CGFloat x=-size.width/2;
        for(NSInteger column=0;column<3;column++){
            if(widths[column]>0 && heights[row]>0){
                SKTexture *part=[SKTexture textureWithRect:CGRectMake(.024+.952*source[column],.024+.952*source[row],.952*(source[column+1]-source[column]),.952*(source[row+1]-source[row])) inTexture:texture];
                SKSpriteNode *tile=[SKSpriteNode spriteNodeWithTexture:part size:CGSizeMake(widths[column],heights[row])];
                tile.color=color; tile.colorBlendFactor=.18; tile.position=CGPointMake(x+widths[column]/2,y+heights[row]/2); [root addChild:tile];
            }
            x+=widths[column];
        }
        y+=heights[row];
    }
    return root;
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
    SKLabelNode *l=[GDCandyLabel labelNodeWithFontNamed:@"AvenirNext-Heavy"];
    l.text=text; l.fontSize=size; l.fontColor=color; l.verticalAlignmentMode=SKLabelVerticalAlignmentModeCenter; l.horizontalAlignmentMode=SKLabelHorizontalAlignmentModeCenter; l.isAccessibilityElement=YES; return l;
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
+ (SKNode *)symbol:(NSString *)name size:(CGFloat)size color:(UIColor *)color {
    UIImageSymbolConfiguration *configuration=[UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightHeavy];
    UIImage *symbol=[UIImage systemImageNamed:name withConfiguration:configuration]; SKNode *root=[SKNode node];
    UIGraphicsBeginImageContextWithOptions(symbol.size,NO,2); [[symbol imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal] drawAtPoint:CGPointZero];
    UIImage *rendered=TrimmedSymbol(UIGraphicsGetImageFromCurrentImageContext()); UIGraphicsEndImageContext();
    CGSize dimensions=CGSizeMake(size*rendered.size.width/MAX(rendered.size.width,rendered.size.height),size*rendered.size.height/MAX(rendered.size.width,rendered.size.height));
    SKTexture *texture=[SKTexture textureWithImage:rendered];
    SKSpriteNode *shadow=[SKSpriteNode spriteNodeWithTexture:texture size:dimensions]; shadow.color=[UIColor colorWithRed:.36 green:.12 blue:.39 alpha:1]; shadow.colorBlendFactor=1; shadow.alpha=.65; shadow.position=CGPointMake(0,-1.5); [root addChild:shadow];
    [root addChild:[SKSpriteNode spriteNodeWithTexture:texture size:dimensions]]; return root;
}
+ (SKSpriteNode *)star:(CGFloat)size {
    SKTexture *texture=[SKTexture textureWithRect:CGRectMake(883/1254.0,1-264/1254.0,95/1254.0,89/1254.0) inTexture:[self image:@"home_hero_v4" size:CGSizeMake(1,1)].texture];
    return [SKSpriteNode spriteNodeWithTexture:texture size:CGSizeMake(size,size*89/95.0)];
}
+ (SKNode *)candyButton:(NSString *)title size:(CGSize)size name:(NSString *)name atlas:(NSString *)atlas row:(NSInteger)row icon:(NSString *)icon fontSize:(CGFloat)fontSize color:(UIColor *)color enabled:(BOOL)enabled {
    SKCropNode *root=[SKCropNode node]; root.name=name; root.maskNode=[self panel:size fill:UIColor.whiteColor stroke:UIColor.clearColor radius:size.height/2]; BOOL utility=[atlas isEqualToString:@"home_footer_v4"];
    const CGFloat mainTop[]={110,493,879},mainBottom[]={411,795,1172},utilityTop[]={108,490,878},utilityBottom[]={400,784,1168};
    CGFloat top=utility?utilityTop[row]:mainTop[row],bottom=utility?utilityBottom[row]:mainBottom[row];
    SKTexture *texture=[self image:atlas size:CGSizeMake(1,1)].texture;
    // Three slices keep capsule ends round even on compact controls.
    CGFloat cap=MIN(size.height/2,size.width/2); CGFloat cuts[]={0,.14,.86,1}, widths[]={cap,MAX(0,size.width-2*cap),cap}; CGFloat x=-size.width/2;
    for(NSInteger i=0;i<3;i++){ if(widths[i]>0){ SKTexture *part=[SKTexture textureWithRect:CGRectMake(.034+.932*cuts[i],1-bottom/1254.0,.932*(cuts[i+1]-cuts[i]),(bottom-top)/1254.0) inTexture:texture]; SKSpriteNode *tile=[SKSpriteNode spriteNodeWithTexture:part size:CGSizeMake(widths[i],size.height)]; tile.position=CGPointMake(x+widths[i]/2,0); [root addChild:tile]; } x+=widths[i]; }
    CGFloat iconLimit=MAX(utility?23:32,fontSize);
    CGFloat iconSize=icon.length?MIN(iconLimit,size.height*.46):0,gap=icon.length?(utility?8:12):0,padding=MIN(utility?16:22,size.height*.24);
    if(title.length){
        SKLabelNode *label=[self label:title size:fontSize color:color]; SKSpriteNode *face=(SKSpriteNode *)[label childNodeWithName:@"textFace"];
        while(face.size.width-2>size.width-iconSize-gap-padding*2 && label.fontSize>11) label.fontSize-=.5;
        CGFloat groupWidth=iconSize+gap+face.size.width-2; label.position=CGPointMake((iconSize+gap)/2,0); [root addChild:label];
        if(!enabled) label.accessibilityTraits=UIAccessibilityTraitNotEnabled;
        if(icon.length){ SKNode *mark=[self symbol:icon size:iconSize color:color]; mark.position=CGPointMake(-groupWidth/2+iconSize/2,0); [root addChild:mark]; }
    } else if(icon.length){ [root addChild:[self symbol:icon size:iconSize color:color]]; root.isAccessibilityElement=YES; root.accessibilityLabel=[name isEqualToString:@"pause"]?@"Pause":name; }
    root.alpha=enabled?1:.48; return root;
}
+ (SKNode *)button:(NSString *)title size:(CGSize)size name:(NSString *)name color:(UIColor *)color {
    CGFloat r=0,g=0,b=0,a=0; [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *atlas=@"home_footer_v4"; NSInteger row=2; UIColor *ink=[UIColor colorWithRed:.35 green:.14 blue:.48 alpha:1];
    if(b>r+.08 && g>r+.1){ atlas=@"home_buttons_v4"; row=0; ink=UIColor.whiteColor; }
    else if(b>r+.03){ atlas=@"home_buttons_v4"; row=1; ink=UIColor.whiteColor; }
    else if(r>.94 && b<.75){ atlas=@"home_buttons_v4"; row=2; ink=[UIColor colorWithRed:.52 green:.15 blue:.17 alpha:1]; }
    else if(r>g+.08){ row=1; }
    else if(b>r){ row=0; }
    NSDictionary *icons=@{@"back":@"chevron.left",@"resume":@"play.fill",@"retry":@"arrow.clockwise",@"settings":@"gearshape.fill",@"home":@"house.fill",@"nextLevel":@"arrow.right",@"allLevels":@"square.grid.2x2.fill",@"levels":@"square.grid.2x2.fill",@"scores":@"trophy.fill",@"privacy":@"doc.text.fill",@"scoresPrev":@"chevron.left",@"scoresNext":@"chevron.right",@"pause":@"pause.fill"};
    NSString *icon=icons[name]; if([name hasPrefix:@"level"] && ![name isEqualToString:@"levels"]) icon=@"play.fill";
    if([name isEqualToString:@"music"] || [name isEqualToString:@"sound"] || [name isEqualToString:@"haptics"] || [name isEqualToString:@"guide"]) icon=[title isEqualToString:@"On"]?@"checkmark":@"xmark";
    return [self candyButton:[name isEqualToString:@"pause"]?@"":title size:size name:name atlas:atlas row:row icon:icon fontSize:MIN(36,size.height*.40) color:ink enabled:YES];
}
@end
