#import <Foundation/Foundation.h>
#import "GDEngine.h"
#import <math.h>

static NSInteger checks;
static void Check(BOOL ok,NSString *message){checks++;if(!ok){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
static GDCell *C(NSInteger r,NSInteger c,GDColor color){return [GDCell row:r column:c color:color];}
static NSArray *Levels(NSDictionary *levels){NSMutableArray *a=[NSMutableArray new];for(NSInteger b=0;b<GDBuffCount;b++)[a addObject:levels[@(b)]?:@0];return a;}
static GDEngine *Fixture(NSArray *cells,GDColor current,GDColor next,NSDictionary *buffs,NSInteger credits){
    GDEngine *e=[[GDEngine alloc]initWithSeed:72];[e loadFixture:cells phase:0 current:current next:next];[e setFixtureEconomyCredits:credits ammo:@[@0,@0,@0,@0] buffs:Levels(buffs)];return e;
}
static GDEngine *Restore(NSDictionary *s){GDEngine *e=[[GDEngine alloc]initWithSnapshot:s];Check(e!=nil,@"valid economy snapshot restores");[e resume];return e;}
static GDShot *Find(GDEngine *e,BOOL match,BOOL bounce){
    for(NSInteger l=0;l<3;l++){[e selectLauncher:l];for(NSInteger x=-1500;x<=2300;x+=10){GDShot *s=[e previewToward:CGPointMake(x,0)];if(s.valid&&(!match||s.expectedMatches.count>=3)&&(!bounce||s.bounced))return s;}}return nil;
}
static void Finish(GDEngine *e){for(NSInteger n=0;n<40&&e.phase==GDPhaseResolving;n++)[e finishResolution];}
static GDEvent *Fire(GDEngine *e,BOOL match,BOOL bounce){GDShot *s=Find(e,match,bounce);Check(s!=nil,@"fixture offers requested trajectory");Check([e beginShot:s],@"preview accepted");GDEvent *v=[e resolveShot];Check(v!=nil,@"shot resolves once");Finish(e);return v;}
static NSArray *MatchBoard(NSInteger falls){NSMutableArray *a=[@[C(0,0,GDColorRed),C(0,8,GDColorBlue),C(0,9,GDColorBlue)] mutableCopy];for(NSInteger i=0;i<falls;i++)[a addObject:C(i+1,8,GDColorYellow)];return a;}
static GDEngine *Shop(NSDictionary *buffs,NSArray *offers,NSInteger credits){GDEngine *e=Fixture(@[C(0,8,GDColorBlue)],GDColorBlue,GDColorWhite,buffs,credits);NSMutableDictionary *s=[e.snapshot mutableCopy],*d=[s[@"economy"] mutableCopy];d[@"offers"]=offers;d[@"shopPending"]=@YES;s[@"economy"]=d;return Restore(s);}

static void InventoryAndRecycling(void){
    GDEngine *e=[[GDEngine alloc]initWithSeed:1];Check(e.economyEnabled&&e.totalAmmo==16&&[e.ammoCounts isEqual:@[@4,@4,@4,@4]],@"new run starts with four rounds per color, including queue");
    NSInteger total=e.totalAmmo;Check([e hold]&&e.totalAmmo==total&&! [e hold],@"hold conserves stock and is limited per shot");GDShot *s=Find(e,NO,NO);NSDictionary *before=e.snapshot;Check([e beginShot:s]&&e.totalAmmo==total-1,@"normal launch spends exactly one physical round");
    Check([Restore(e.snapshot).snapshot isEqual:before],@"cold restore refunds the whole unlanded shot checkpoint");[e resolveShot];Finish(e);Check(e.totalAmmo==total-1,@"settled non-falling shot remains spent");
    e=Fixture(MatchBoard(4),GDColorBlue,GDColorWhite,@{},0);GDEvent *v=Fire(e,YES,NO);
    Check(v.removed.count==3&&v.fallen.count==4&&v.points==90&&e.score==90&&e.credits==90,@"large support collapse retains full removal, fall and score results");
    Check(e.ammoCounts[GDColorBlue].integerValue==0&&e.ammoCounts[GDColorYellow].integerValue==1&&e.materials[GDColorYellow].integerValue==1,@"only fallen pieces recycle: three yellow yield one round and one remainder");
    Check(e.energy[GDColorBlue].integerValue==3&&e.energy[GDColorYellow].integerValue==4,@"normal direct and fallen candies charge their own color");
    [e loadFixture:MatchBoard(2) phase:0 current:GDColorBlue next:GDColorYellow];Fire(e,YES,NO);Check(e.materials[GDColorYellow].integerValue==0&&e.ammoCounts[GDColorYellow].integerValue==2,@"remainders persist and combine with later falls");
    e=Fixture(MatchBoard(4),GDColorWhite,GDColorRed,@{},0);[e setFixtureEnergy:@[@0,@0,@0,@20]];[e activateSkill:GDColorWhite];s=nil;
    for(NSInteger l=0;l<3&&!s;l++){[e selectLauncher:l];for(NSInteger x=-1500;x<=2300;x+=10){GDShot *candidate=[e previewToward:CGPointMake(x,0)];if(candidate.valid&&candidate.expectedMatches.count>=3&&candidate.resolvedColor==GDColorBlue){s=candidate;break;}}}
    Check(s&&[e beginShot:s],@"wild can select the blue support bridge");v=[e resolveShot];Finish(e);Check(v.source==GDSourceWild&&e.ammoCounts[GDColorYellow].integerValue==1&&[e.energy isEqual:@[@0,@0,@0,@0]],@"wild-caused falls recycle without refunding any energy");
    // A blast removes the bridge; the remote lower tail lies outside its radius.
    NSMutableArray *bridge=[NSMutableArray arrayWithObject:C(0,0,GDColorWhite)];for(NSInteger r=0;r<8;r++)[bridge addObject:C(r,8,r<3?GDColorRed:GDColorYellow)];
    e=Fixture(bridge,GDColorBlue,GDColorWhite,@{},0);[e setFixtureEnergy:@[@0,@20,@0,@0]];[e activateSkill:GDColorRed];[e selectLauncher:0];s=[e previewToward:[e centerOfCell:C(0,8,GDColorRed)]];
    Check(s.valid&&s.blast,@"bridge blast is reachable");[e beginShot:s];v=[e resolveShot];Finish(e);Check(v.fallen.count>=3&&e.ammoCounts[GDColorYellow].integerValue>=1&&e.totalAmmo>=3,@"blast-caused remote falls recycle and blast preserves loaded rounds");
    Check([e.energy isEqual:@[@0,@0,@0,@0]],@"blast direct and fallen removals never generate energy");
    NSLog(@"PASS: finite queue, flight refunds, support collapse, color remainders and skill-source recycling");
}
static void SupplyAndShop(void){
    GDEngine *e=Fixture(@[C(0,0,GDColorRed)],GDColorBlue,GDColorWhite,@{@(GDBuffSupply):@2,@(GDBuffRecolor):@2},1000);NSInteger score=e.score,ammo=e.totalAmmo;
    Check([e buyAmmo:GDColorYellow count:2]&&e.totalAmmo==ammo+3&&e.credits==800&&e.score==score,@"first two-pack receives bonus and spends balance without reducing score");
    Check([e buyAmmo:GDColorYellow count:2]&&[e buyAmmo:GDColorYellow count:2]&&e.ammoCounts[GDColorYellow].integerValue==8,@"level two grants exactly two bonus purchases per wave");
    Check(![e buyAmmo:GDColorRed count:3]&&![e buyAmmo:(GDColor)4 count:1],@"supply rejects invalid quantities and colors");
    Check([e recolorCurrentTo:GDColorRed]&&[e recolorCurrentTo:GDColorYellow]&&! [e recolorCurrentTo:GDColorBlue]&&e.totalAmmo==ammo+8,@"color swaps conserve ammo and stop at wave allowance");
    Check(Restore(e.snapshot).recolorsRemaining==0,@"swap and supply counters persist");
    e=Shop(@{},@[@(GDBuffRecolor),@(GDBuffDoubleHold),@(GDBuffRescue)],1000);NSDictionary *before=e.snapshot;[e advanceTime:1000];Check([e.snapshot isEqual:before],@"wave shop stops elapsed, pressure and freeze clocks");
    Check(![e buyBuff:GDBuffEmergency]&&e.credits==1000,@"only offered upgrades can be bought");
    Check([e buyBuff:GDBuffRecolor]&&e.phase==GDPhaseReady&&e.credits==800&&[e buffLevel:GDBuffRecolor]==1,@"buy one offered buff closes shop and applies level one");
    Check(![e buyBuff:GDBuffDoubleHold],@"second buff cannot be bought after choice");
    for(NSInteger level=1;level<=3;level++){e=Shop(@{@(GDBuffRecolor):@(level-1)},@[@(GDBuffRecolor)],2000);NSInteger price=[GDBuffCatalog price:GDBuffRecolor level:level];Check([e buyBuff:GDBuffRecolor]&&e.credits==2000-price&&e.recolorsRemaining==level,@"upgrade charges current tier price and increases effect");}
    Check([e nextBuffPrice:GDBuffRecolor]==0,@"maxed buff has no further purchase");
    e=Shop(@{@(GDBuffBankWild):@1},@[@(GDBuffBankWild)],1000);NSMutableDictionary *progress=[e.snapshot mutableCopy],*economy=[progress[@"economy"] mutableCopy];economy[@"bankMatches"]=@4;progress[@"economy"]=economy;e=Restore(progress);Check([e buyBuff:GDBuffBankWild]&&e.bankWildReady&&e.bankMatches==0&&Restore(e.snapshot).bankWildReady,@"bank upgrade honors progress already reaching its new threshold and remains restorable");
    e=Shop(@{},@[@(GDBuffRescue)],799);Check(![e buyBuff:GDBuffRescue]&&e.credits==799&&[e skipShop],@"unaffordable buff leaves balance intact and skip stays available");
    e=Fixture(@[C(0,8,GDColorBlue),C(0,9,GDColorBlue)],GDColorBlue,GDColorWhite,@{},0);GDEvent *v=Fire(e,YES,NO);Check(v.newWave&&e.phase==GDPhaseShop&&e.shopOffers.count==3&&e.pressureRemaining==e.pressureInterval,@"completed wave generates three unique upgrades and resets pressure");
    Check([NSSet setWithArray:e.shopOffers].count==3&&[Restore(e.snapshot).shopOffers isEqual:e.shopOffers],@"offer roll is stable across cold restore");
    e=Fixture(@[C(0,0,GDColorRed)],GDColorBlue,GDColorWhite,@{@(GDBuffDoubleHold):@1},500);Check([e holdSlot:1]&&e.secondHeldColor==GDColorBlue&&e.totalAmmo==2&&! [e holdSlot:0],@"second hold slot conserves rounds and shares per-shot swap lock");Fire(e,NO,NO);Check([e holdSlot:1]&&e.currentColor==GDColorBlue&&e.totalAmmo==1,@"last held round can be restored to an empty chamber");
    NSLog(@"PASS: purchases, score isolation, buff prices and tiers, paused shop, deterministic offers and double hold");
}
static void Exhaustion(void){
    GDEngine *e=Fixture(@[C(0,0,GDColorRed)],GDColorBlue,(GDColor)-1,@{},0);Fire(e,NO,NO);Check(e.phase==GDPhaseGameOver,@"zero ammo without credits or escape ends run");
    e=Fixture(@[C(0,0,GDColorRed)],GDColorBlue,(GDColor)-1,@{},100);Fire(e,NO,NO);Check(e.phase==GDPhaseReady&&e.currentColor<0&&!Find(e,NO,NO),@"empty chamber blocks shots but allows affordable resupply");Check([e buyAmmo:GDColorRed count:1]&&e.currentColor==GDColorRed&&e.credits==0,@"buying a final round immediately refills chamber");
    e=Fixture(@[C(0,0,GDColorRed)],GDColorBlue,(GDColor)-1,@{@(GDBuffEmergency):@2},0);Fire(e,NO,NO);Check(e.totalAmmo==2&&[e.snapshot[@"economy"][@"emergencyUsed"] boolValue],@"empty stock grants level two emergency rounds");
    [e loadFixture:@[C(0,8,GDColorBlue),C(0,9,GDColorBlue)] phase:0 current:GDColorBlue next:(GDColor)-1];[e setFixtureEconomyCredits:0 ammo:@[@0,@0,@0,@0] buffs:Levels(@{@(GDBuffEmergency):@2})];Fire(e,YES,NO);Check(e.phase==GDPhaseShop&&[e skipShop]&&e.totalAmmo==2,@"new wave resets emergency allowance before leaving shop");
    [e loadFixture:@[C(0,0,GDColorRed)] phase:0 current:GDColorBlue next:(GDColor)-1];[e setFixtureEconomyCredits:0 ammo:@[@0,@0,@0,@0] buffs:Levels(@{@(GDBuffEmergency):@2})];Fire(e,NO,NO);Check(e.phase==GDPhaseGameOver,@"emergency cannot trigger twice within a wave");
    for(GDColor c=GDColorRed;c<=GDColorYellow;c++){e=Fixture(@[C(0,0,GDColorRed)],GDColorBlue,(GDColor)-1,@{},0);NSMutableArray *energy=[@[@0,@0,@0,@0] mutableCopy];energy[c]=@20;[e setFixtureEnergy:energy];Fire(e,NO,NO);Check(e.phase==GDPhaseReady,@"charged clearing skill keeps an empty-ammo run playable");}
    NSLog(@"PASS: depletion, resupply, emergency once per wave and zero-ammo skill escapes");
}
static void SkillBuffs(void){
    GDEngine *e=Fixture(MatchBoard(0),GDColorBlue,GDColorWhite,@{@(GDBuffBankEnergy):@3,@(GDBuffBankWild):@3},1000);
    for(NSInteger i=0;i<3;i++){[e loadFixture:MatchBoard(0) phase:0 current:GDColorBlue next:GDColorWhite];Fire(e,YES,YES);}
    Check(e.energy[GDColorBlue].integerValue==18&&e.bankWildReady&&e.bankMatches==0,@"bank matches add original-color energy and grant wildcard at level three threshold");
    [e loadFixture:MatchBoard(0) phase:0 current:GDColorBlue next:GDColorWhite];GDShot *s=Find(e,YES,NO);NSDictionary *before=e.snapshot;Check(s.wildcard&&[e beginShot:s]&&!e.bankWildReady,@"bank wildcard is consumed by one accepted normal shot");Check(Restore(e.snapshot).bankWildReady&&[e.snapshot isEqual:before],@"unlanded bank wildcard refunds with checkpoint");GDEvent *v=[e resolveShot];Finish(e);Check(v.source==GDSourceWild&&e.energy[GDColorBlue].integerValue==18,@"bank wildcard does not recursively earn energy or bank progress");
    e=Fixture(@[],GDColorBlue,GDColorWhite,@{@(GDBuffDoubleBounce):@1},100);BOOL found=NO;for(NSInteger x=-1800;x<0;x+=10){s=[e previewToward:CGPointMake(x,0)];if(s.valid&&s.points.count>=5){found=YES;break;}}Check(found,@"double-bounce upgrade opens a valid two-wall trajectory");
    e=Fixture(@[C(0,8,GDColorBlue),C(0,9,GDColorRed)],GDColorWhite,GDColorBlue,@{@(GDBuffWildChoice):@1},100);[e setFixtureEnergy:@[@0,@0,@0,@20]];[e activateSkill:GDColorWhite];Check([e selectWildColor:GDColorRed],@"wild color selection enabled by buff");s=[e previewToward:CGPointMake(414,0)];Check(s.valid&&s.resolvedColor==GDColorRed,@"manual neighbor color overrides automatic tie");[e selectWildColor:GDColorYellow];s=[e previewToward:CGPointMake(414,0)];Check(s.resolvedColor==GDColorBlue,@"unavailable manual color falls back to legal automatic choice");
    e=Fixture(MatchBoard(0),GDColorBlue,GDColorWhite,@{@(GDBuffOverflow):@1},100);[e setFixtureEnergy:@[@19,@0,@0,@0]];Fire(e,YES,NO);Check(e.energy[0].integerValue==20&&e.overflowEnergy[0].integerValue==2,@"normal excess energy enters reserve");Check([e activateSkill:GDColorBlue]&&e.energy[0].integerValue==2&&e.overflowEnergy[0].integerValue==0,@"skill use transfers reserve into next charge");
    e=Fixture(MatchBoard(0),GDColorBlue,GDColorWhite,@{@(GDBuffIceReserve):@2,@(GDBuffBankEnergy):@3},100);[e setFixtureEnergy:@[@20,@0,@0,@0]];[e activateSkill:GDColorBlue];Fire(e,YES,YES);Check(e.energy[0].integerValue==0&&[e.snapshot[@"economy"][@"iceBank"] integerValue]==5,@"freeze stores normal and bank energy up to the upgraded cap");e=Restore(e.snapshot);[e advanceTime:30];Check(e.energy[0].integerValue==5&&e.pressureRemaining==12,@"freeze expiry releases reserve without advancing row clock during freeze");
    NSMutableArray *column=[NSMutableArray new];for(NSInteger r=0;r<6;r++)for(NSInteger c=7;c<=9;c++)[column addObject:C(r,c,(r+c)%4)];
    for(NSInteger level=1;level<=3;level++){e=Fixture(column,GDColorBlue,GDColorWhite,@{@(GDBuffVerticalBlast):@(level)},100);[e setFixtureEnergy:@[@0,@20,@0,@0]];Check([e toggleVerticalBlast]&&[e activateSkill:GDColorRed],@"directional blast is selectable");s=[e previewToward:[e centerOfCell:C(5,8,GDColorBlue)]];Check(s.valid&&s.verticalBlast&&s.expectedMatches.count==level+2,@"cut reaches exactly the upgraded upward row count");[e beginShot:s];v=[e resolveShot];Check(v.removed.count==s.expectedMatches.count,@"cut preview and actual removal agree");}
    e=Fixture(column,GDColorBlue,GDColorWhite,@{@(GDBuffSweepDelay):@3},100);[e setFixtureEnergy:@[@0,@0,@20,@0]];NSTimeInterval pressure=e.pressureRemaining;[e activateYellow];Finish(e);Check(e.pressureRemaining==pressure+6,@"sweep buffer delays next pressure by upgraded six seconds");
    e=Fixture(@[C(0,8,GDColorBlue)],GDColorBlue,GDColorWhite,@{@(GDBuffSweepDelay):@3},100);[e setFixtureEnergy:@[@0,@0,@20,@0]];[e activateYellow];Finish(e);Check(e.phase==GDPhaseShop&&e.pressureRemaining==e.pressureInterval+6,@"sweep delay survives a wave-clearing reset");
    NSLog(@"PASS: bank energy/wild, double bounce, manual wild, overflow, ice reserve, upward cut and sweep delay");
}
static void RescueAndPersistence(void){
    NSMutableArray *a=[NSMutableArray new];for(NSInteger r=0;r<=8;r++)[a addObject:C(r,8,GDColorRed)];
    GDEngine *e=Fixture(a,GDColorBlue,GDColorWhite,@{@(GDBuffRescue):@1,@(GDBuffSupply):@1},500);[e setFixtureEnergy:@[@4,@8,@3,@7]];NSArray *energy=e.energy;NSInteger ammo=e.totalAmmo;GDEvent *v=[e advanceTime:12];Finish(e);
    Check(v.rescued&&!v.gameOver&&v.rescuedCells.count==26&&e.rescueUsed&&e.wave==2&&e.phase==GDPhaseReady,@"one-row-before-danger rescue clears pressure board and continues next wave");
    Check(e.score==500&&e.credits==500&&e.totalAmmo==ammo+3&&[e.materials isEqual:@[@0,@0,@0,@0]]&&[e.energy isEqual:energy],@"rescue grants only three rounds, preserving score, balance and skill charge");
    e=Restore(e.snapshot);Check(e.rescueUsed&&[e buffLevel:GDBuffSupply]==1,@"rescue consumption and other run buffs persist");
    [e loadFixture:a phase:0 current:GDColorBlue next:GDColorWhite];v=[e advanceTime:12];Finish(e);Check(!v.rescued&&e.phase==GDPhaseReady,@"consumed rescue cannot clear board again");v=[e advanceTime:12];Check(v.gameOver&&!v.rescued,@"second danger crossing loses normally");
    NSDictionary *good=Shop(@{@(GDBuffDoubleHold):@1,@(GDBuffWildChoice):@1},@[@(GDBuffRecolor)],1000).snapshot;
    for(NSString *key in @[@"materials",@"buffs",@"offers",@"credits",@"secondHeld",@"iceBank",@"bankWild",@"rescueUsed"]){NSMutableDictionary *s=[good mutableCopy],*d=[good[@"economy"] mutableCopy];if([key isEqual:@"materials"])d[key]=@[@3,@0,@0,@0];else if([key isEqual:@"buffs"]){NSMutableArray *b=[d[key] mutableCopy];b[0]=@4;d[key]=b;}else if([key isEqual:@"offers"])d[key]=@[@0,@0];else if([key isEqual:@"credits"])d[key]=@1001;else if([key isEqual:@"secondHeld"])d[key]=@4;else d[key]=@1;s[@"economy"]=d;Check(![[GDEngine alloc]initWithSnapshot:s],[NSString stringWithFormat:@"reject malformed economy %@",key]);}
    e=[[GDEngine alloc]initWithLevelID:1 seed:1];Check(!e.economyEnabled&&! [e buyAmmo:GDColorBlue count:1]&&Restore(e.snapshot).mode==GDGameModeLevel,@"campaign retains previous unlimited queue and separate compatible snapshots");
    NSMutableDictionary *legacy=[[[GDEngine alloc]initWithSeed:1].snapshot mutableCopy];legacy[@"format"]=@2;[legacy removeObjectForKey:@"economy"];Check(!Restore(legacy).economyEnabled,@"legacy endless saves finish under their original rules");
    NSLog(@"PASS: one-use rescue accounting, cold restore, malformed saves and legacy/campaign compatibility");
}
static void BoundedRuns(void){
    NSInteger shots=0,buys=0,waves=0;
    for(NSUInteger seed=1;seed<=8;seed++){@autoreleasepool{
        GDEngine *e=[[GDEngine alloc]initWithSeed:seed];
        for(NSInteger step=0;step<45&&e.phase!=GDPhaseGameOver;step++){
            if(e.phase==GDPhaseShop){waves++;BOOL bought=NO;for(NSNumber *offer in e.shopOffers)if([e buyBuff:offer.integerValue]){bought=YES;break;}if(!bought)[e skipShop];}
            if(e.phase!=GDPhaseReady)break;
            if(e.totalAmmo<=3&&e.credits>=100){if([e buyAmmo:e.cells.firstObject.color count:1])buys++;}
            if(e.energy[2].integerValue>=[e energyThresholdForColor:GDColorYellow]){[e activateYellow];Finish(e);continue;}
            if(e.energy[1].integerValue>=[e energyThresholdForColor:GDColorRed])[e activateSkill:GDColorRed];
            GDShot *s=Find(e,YES,NO);if(!s){[e hold];s=Find(e,YES,NO);}if(!s)s=Find(e,NO,NO);if(!s){[e advanceTime:12];Finish(e);continue;}
            Check([e beginShot:s],@"bounded run accepts current preview");[e advanceTime:.3];GDEvent *v=[e resolveShot];Check(v!=nil,@"bounded run settles");Finish(e);[e advanceTime:.5];Finish(e);shots++;
            Check(e.credits>=0&&e.credits<=e.score&&e.totalAmmo>=0,@"real generated run maintains balances");for(NSNumber *n in e.materials)Check(n.integerValue>=0&&n.integerValue<3,@"recycling remnants stay bounded");
            GDEngine *cold=Restore(e.snapshot);Check([cold.snapshot isEqual:e.snapshot],@"generated run cold snapshot round-trips every field");
        }
    }}
    Check(shots>=80&&buys>0,@"generated runs exercise finite stock and real resupply");NSLog(@"Bounded economy audit: 8 seeds, %ld shots, %ld supply purchases, %ld wave shops",(long)shots,(long)buys,(long)waves);
}
int main(void){@autoreleasepool{InventoryAndRecycling();SupplyAndShop();Exhaustion();SkillBuffs();RescueAndPersistence();BoundedRuns();NSLog(@"PASS: economy validation (%ld assertions)",(long)checks);}}
