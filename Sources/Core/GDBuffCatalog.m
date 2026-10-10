#import "GDBuffCatalog.h"

@implementation GDBuffCatalog
+ (NSArray *)prices {
    return @[@[@200,@350,@600],@[@350],@[@300,@500,@800],@[@250,@450,@750],
             @[@400],@[@300,@500,@850],@[@250,@450,@750],@[@250,@450,@750],
             @[@350],@[@250,@450,@750],@[@300,@550,@900],@[@200,@350,@600],@[@800]];
}
+ (NSString *)title:(GDBuff)b {
    if(b<0||b>=GDBuffCount)return @"";
    return @[@"Color Swap",@"Double Hold",@"Last Round",@"Supply Bonus",@"Double Bounce",
             @"Bank Shot",@"Bank Energy",@"Energy Reserve",@"Wild Choice",@"Ice Reserve",
             @"Vertical Blast",@"Sweep Buffer",@"Rescue Charm"][b];
}
+ (NSString *)symbol:(GDBuff)b {
    return @[@"paintpalette.fill",@"tray.2.fill",@"cross.case.fill",@"shippingbox.fill",@"arrow.triangle.turn.up.right.diamond.fill",
             @"sparkles",@"bolt.fill",@"battery.100",@"wand.and.stars",@"snowflake",@"arrow.up",@"clock.fill",@"shield.fill"][b];
}
+ (NSInteger)maximumLevel:(GDBuff)b { return b>=0&&b<GDBuffCount?[[self prices][b] count]:0; }
+ (NSInteger)price:(GDBuff)b level:(NSInteger)level {
    return level>0&&level<=[self maximumLevel:b]?[[self prices][b][level-1] integerValue]:0;
}
+ (NSString *)effect:(GDBuff)b level:(NSInteger)level {
    NSInteger n=MAX(1,MIN(level,[self maximumLevel:b]));
    switch(b){
        case GDBuffRecolor:return [NSString stringWithFormat:@"Change %ld loaded round%@ each wave.",(long)n,n==1?@"":@"s"];
        case GDBuffDoubleHold:return @"Two hold slots. One swap per shot.";
        case GDBuffEmergency:return [NSString stringWithFormat:@"When empty: %ld random round%@. Once per wave.",(long)n,n==1?@"":@"s"];
        case GDBuffSupply:return [NSString stringWithFormat:@"First %ld two-round purchases each wave: +1 free.",(long)n];
        case GDBuffDoubleBounce:return @"Shots can bounce off walls twice.";
        case GDBuffBankWild:return [NSString stringWithFormat:@"Every %ld normal bank-shot matches: one wild shot.",(long)(6-n)];
        case GDBuffBankEnergy:return [NSString stringWithFormat:@"Normal bank-shot matches: +%ld energy in that color.",(long)n];
        case GDBuffOverflow:return [NSString stringWithFormat:@"Store up to %ld spare energy per color.",(long)[@[@5,@8,@10][n-1] integerValue]];
        case GDBuffWildChoice:return @"Choose a neighboring color for wild shots.";
        case GDBuffIceReserve:return [NSString stringWithFormat:@"Store up to %ld blue energy during Freeze. Gain it after.",(long)[@[@3,@5,@8][n-1] integerValue]];
        case GDBuffVerticalBlast:return [NSString stringWithFormat:@"Blast can cut upward through %ld grid rows.",(long)(n+2)];
        case GDBuffSweepDelay:return [NSString stringWithFormat:@"Sweep delays the next row by %ld seconds.",(long)(n*2)];
        case GDBuffRescue:return @"Near the danger line: clear the board and gain 3 rounds. Once per run.";
        default:return @"";
    }
}
@end
