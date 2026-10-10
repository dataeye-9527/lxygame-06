#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GDBuff) {
    GDBuffRecolor, GDBuffDoubleHold, GDBuffEmergency, GDBuffSupply,
    GDBuffDoubleBounce, GDBuffBankWild, GDBuffBankEnergy, GDBuffOverflow,
    GDBuffWildChoice, GDBuffIceReserve, GDBuffVerticalBlast, GDBuffSweepDelay,
    GDBuffRescue, GDBuffCount
};

@interface GDBuffCatalog : NSObject
+ (NSString *)title:(GDBuff)buff;
+ (NSString *)symbol:(GDBuff)buff;
+ (NSInteger)maximumLevel:(GDBuff)buff;
+ (NSInteger)price:(GDBuff)buff level:(NSInteger)level;
+ (NSString *)effect:(GDBuff)buff level:(NSInteger)level;
@end
