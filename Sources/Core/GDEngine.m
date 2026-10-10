#import "GDEngine.h"
#import "GDLevelCatalog.h"
#import "GDProgressStore.h"
#import "GDRunRecords.h"
#import <math.h>

static const NSTimeInterval GDFreezeDuration=30;
static const NSInteger GDYellowSweepRows=4;
static const NSInteger GDWildShots=5, GDEnergyBase=20, GDEnergyMaximum=50;
static NSString *GDSkillUseKey(GDColor color) { return @[@"blueUses",@"redUses",@"yellowUses",@"whiteUses"][color]; }
static NSString *GDKey(NSInteger row, NSInteger col) { return [NSString stringWithFormat:@"%ld:%ld", (long)row, (long)col]; }
static CGFloat GDLength(CGPoint p) { return hypot(p.x, p.y); }
static CGPoint GDAdd(CGPoint a, CGPoint b) { return CGPointMake(a.x+b.x, a.y+b.y); }
static CGPoint GDScale(CGPoint p, CGFloat s) { return CGPointMake(p.x*s,p.y*s); }
static CGPoint GDSub(CGPoint a, CGPoint b) { return CGPointMake(a.x-b.x,a.y-b.y); }
static CGFloat GDDot(CGPoint a, CGPoint b) { return a.x*b.x+a.y*b.y; }
static NSValue *GDPoint(CGPoint p) { return [NSValue value:&p withObjCType:@encode(CGPoint)]; }
static CGPoint GDReadPoint(NSValue *v) { CGPoint p; [v getValue:&p]; return p; }
static CGFloat GDSegmentDistance(CGPoint p, CGPoint a, CGPoint b) {
    CGPoint d=GDSub(b,a); CGFloat n=GDDot(d,d);
    CGFloat t=n>0?fmax(0,fmin(1,GDDot(GDSub(p,a),d)/n)):0;
    return GDLength(GDSub(p,GDAdd(a,GDScale(d,t))));
}
@implementation GDCell
+ (instancetype)row:(NSInteger)row column:(NSInteger)column color:(GDColor)color { GDCell *c=[self new]; c.row=row;c.column=column;c.color=color;return c; }
- (NSString *)key { return GDKey(self.row,self.column); }
- (id)copyWithZone:(NSZone *)zone { return [GDCell row:self.row column:self.column color:self.color]; }
@end
@implementation GDShot
- (instancetype)init { if((self=[super init])) { _points=@[];_expectedMatches=@[];_reason=@"No legal landing";_landingRow=-1;_landingColumn=-1; } return self; }
@end
@implementation GDEvent
- (instancetype)init { if((self=[super init])) { _removed=@[];_fallen=@[];_rescuedCells=@[]; } return self; }
@end
@interface GDEngine () {
    NSMutableDictionary<NSString *,GDCell *> *_board;
    NSMutableArray<NSNumber *> *_mutableEnergy;
    NSMutableDictionary *_stats;
    NSMutableArray *_operations;
    uint64_t _rng;
    NSTimeInterval _difficultyTime;
    GDPhase _phaseBeforePause;
    GDShot *_activeShot, *_lastPreview;
    NSDictionary *_flightCheckpoint;
    BOOL _activeResolvingBounce;
    GDLevel *_level;
    NSInteger _clearedWaves, _collected, _fallenTotal;
    BOOL _completionRecorded;
    NSMutableArray<NSNumber *> *_ammo, *_materials, *_buffLevels, *_overflow;
    BOOL _economyEnabled, _shopPending, _emergencyUsed, _bankWildReady, _rescueUsed, _verticalBlast, _chamberSpent;
    NSInteger _credits, _secondHeldColor, _selectedWildColor, _recolorsUsed, _ammoPurchases, _bankMatches, _freezeBank;
    NSArray<NSNumber *> *_shopOffers;
}
@property(nonatomic) GDGameMode mode;
@property(nonatomic) NSInteger levelID, stars;
@property(nonatomic, copy) NSString *runID;
@property(nonatomic) NSInteger rowPhase, revision;
@property(nonatomic) GDPhase phase;
@property(nonatomic) GDColor currentColor, nextColor;
@property(nonatomic) NSInteger heldColor;
@property(nonatomic) BOOL holdUsed, blastArmed, pressurePending;
@property(nonatomic) NSInteger launcher, wildRemaining, score, bestScore, wave;
@property(nonatomic) NSUInteger seed;
@property(nonatomic) NSTimeInterval pressureRemaining, freezeRemaining, elapsed;
@end
@implementation GDEngine
- (CGFloat)radius { return 23; }
- (CGFloat)blastRadius { return 4*self.radius; }
- (CGFloat)boardWidth { return self.radius*36; }
- (CGFloat)dangerY { return 432; }
- (CGFloat)launchY { return 516; }
- (NSInteger)longColumns { return 18; }
- (NSInteger)initialRows { return 6; }
- (BOOL)economyEnabled { return _economyEnabled; }
- (NSInteger)credits { return _credits; }
- (NSInteger)secondHeldColor { return _secondHeldColor; }
- (NSInteger)selectedWildColor { return _selectedWildColor; }
- (BOOL)verticalBlast { return _verticalBlast; }
- (BOOL)bankWildReady { return _bankWildReady; }
- (NSInteger)bankMatches { return _bankMatches; }
- (BOOL)rescueUsed { return _rescueUsed; }
- (NSArray *)materials { return [_materials copy]; }
- (NSArray *)buffLevels { return [_buffLevels copy]; }
- (NSArray *)overflowEnergy { return [_overflow copy]; }
- (NSArray *)shopOffers { return _shopOffers; }
- (NSInteger)buffLevel:(GDBuff)buff { return _economyEnabled&&buff>=0&&buff<GDBuffCount?_buffLevels[buff].integerValue:0; }
- (NSInteger)nextBuffPrice:(GDBuff)buff { return [GDBuffCatalog price:buff level:[self buffLevel:buff]+1]; }
- (NSInteger)recolorsRemaining { return MAX(0,[self buffLevel:GDBuffRecolor]-_recolorsUsed); }
- (NSArray *)ammoCounts {
    NSMutableArray<NSNumber *> *counts=[_ammo mutableCopy];
    if(!_economyEnabled)return @[@0,@0,@0,@0];
    if(self.currentColor>=0&&!_chamberSpent)counts[self.currentColor]=@(counts[self.currentColor].integerValue+1);
    for(NSNumber *color in @[@(self.nextColor),@(self.heldColor),@(_secondHeldColor)])if(color.integerValue>=0)counts[color.integerValue]=@(counts[color.integerValue].integerValue+1);
    return counts;
}
- (NSInteger)totalAmmo { NSInteger total=0;for(NSNumber *n in self.ammoCounts)total+=n.integerValue;return total; }
- (GDColor)queueColor {
    if(!_economyEnabled)return [self legacyQueueColor];
    NSMutableIndexSet *available=[NSMutableIndexSet new],*preferred=[NSMutableIndexSet new];
    for(NSInteger color=0;color<4;color++)if(_ammo[color].integerValue>0)[available addIndex:color];
    for(GDCell *cell in self.cells)if([available containsIndex:cell.color])[preferred addIndex:cell.color];
    NSIndexSet *choices=preferred.count?preferred:available;if(!choices.count)return (GDColor)-1;
    NSUInteger pick=[self random]%choices.count,color=choices.firstIndex;while(pick--)color=[choices indexGreaterThanIndex:color];
    _ammo[color]=@(_ammo[color].integerValue-1);return (GDColor)color;
}
- (void)refillQueue {
    if(self.currentColor<0){self.currentColor=self.nextColor;self.nextColor=(GDColor)-1;if(self.currentColor<0)self.currentColor=[self queueColor];}
    if(self.nextColor<0)self.nextColor=[self queueColor];
}
- (void)addRandomAmmo { NSMutableIndexSet *colors=[NSMutableIndexSet new];for(GDCell *cell in self.cells)[colors addIndex:cell.color];if(!colors.count)[colors addIndexesInRange:NSMakeRange(0,4)];NSUInteger pick=[self random]%colors.count,color=colors.firstIndex;while(pick--)color=[colors indexGreaterThanIndex:color];_ammo[color]=@(_ammo[color].integerValue+1); }
- (void)resetWaveEconomy { _emergencyUsed=NO;_recolorsUsed=0;_ammoPurchases=0; }
- (void)rollShop {
    NSMutableArray *eligible=[NSMutableArray new];for(GDBuff buff=0;buff<GDBuffCount;buff++)if([self nextBuffPrice:buff]>0&&!(buff==GDBuffRescue&&_rescueUsed))[eligible addObject:@(buff)];
    NSMutableArray *offers=[NSMutableArray new];while(offers.count<3&&eligible.count){NSUInteger index=[self random]%eligible.count;[offers addObject:eligible[index]];[eligible removeObjectAtIndex:index];}_shopOffers=[offers copy];
}
- (void)addEnergy:(NSInteger)amount color:(GDColor)color {
    if(amount<=0||color<0||color>3)return;
    if(color==GDColorBlue&&self.freezeRemaining>0){NSInteger level=[self buffLevel:GDBuffIceReserve];if(level){NSInteger cap=[@[@3,@5,@8][level-1] integerValue];_freezeBank=MIN(cap,_freezeBank+amount);}return;}
    NSInteger old=_mutableEnergy[color].integerValue,threshold=[self energyThresholdForColor:color],value=old+amount;
    _mutableEnergy[color]=@(MIN(threshold,value));NSInteger level=[self buffLevel:GDBuffOverflow];
    if(level&&value>threshold)_overflow[color]=@(MIN(([@[@5,@8,@10][level-1] integerValue]),_overflow[color].integerValue+value-threshold));
    if(old<threshold&&value>=threshold)[self increment:[NSString stringWithFormat:@"energy%ldFull",(long)color] by:1];
}
- (void)prepareAmmo {
    if(!_economyEnabled||self.phase!=GDPhaseReady)return;
    [self refillQueue];NSInteger emergency=[self buffLevel:GDBuffEmergency];
    if(self.totalAmmo==0&&emergency&&!_emergencyUsed){_emergencyUsed=YES;for(NSInteger i=0;i<emergency;i++)[self addRandomAmmo];[self refillQueue];[self record:@"emergencyAmmo"];}
    BOOL escape=(_mutableEnergy[GDColorRed].integerValue>=[self energyThresholdForColor:GDColorRed]&&self.cells.count)||(_mutableEnergy[GDColorYellow].integerValue>=[self energyThresholdForColor:GDColorYellow]&&self.cells.count)||([self buffLevel:GDBuffRescue]&&!_rescueUsed);
    if(!self.totalAmmo&&_credits<100&&!escape){self.phase=GDPhaseGameOver;self.blastArmed=NO;[self record:@"outOfAmmo"];[self persistCompletion];}
}
- (BOOL)buyAmmo:(GDColor)color count:(NSInteger)count {
    if(!_economyEnabled||(self.phase!=GDPhaseReady&&self.phase!=GDPhaseShop)||self.pressurePending||self.blastArmed||color<0||color>3||(count!=1&&count!=2)||_credits<count*100)return NO;
    _credits-=count*100;NSInteger bonus=count==2&&_ammoPurchases<[self buffLevel:GDBuffSupply]?1:0;if(count==2)_ammoPurchases++;
    _ammo[color]=@(_ammo[color].integerValue+count+bonus);[self refillQueue];self.revision++;_lastPreview=nil;[self record:@"buyAmmo"];return YES;
}
- (BOOL)buyBuff:(GDBuff)buff {
    NSInteger price=[self nextBuffPrice:buff];if(!_economyEnabled||self.phase!=GDPhaseShop||![_shopOffers containsObject:@(buff)]||price<=0||_credits<price||(buff==GDBuffRescue&&_rescueUsed))return NO;
    _credits-=price;_buffLevels[buff]=@([self buffLevel:buff]+1);
    if(buff==GDBuffBankWild&&_bankMatches>=6-[self buffLevel:buff]){_bankMatches=0;_bankWildReady=YES;}
    [self record:@"buyBuff"];[self skipShop];return YES;
}
- (BOOL)skipShop { if(!_economyEnabled||self.phase!=GDPhaseShop)return NO;_shopPending=NO;_shopOffers=@[];self.phase=GDPhaseReady;[self prepareAmmo];return YES; }
- (BOOL)recolorCurrentTo:(GDColor)color {
    if(!_economyEnabled||self.phase!=GDPhaseReady||self.pressurePending||self.blastArmed||self.currentColor<0||color<0||color>3||color==self.currentColor||self.recolorsRemaining==0)return NO;
    self.currentColor=color;_recolorsUsed++;self.revision++;_lastPreview=nil;[self record:@"recolor"];return YES;
}
- (BOOL)selectWildColor:(NSInteger)color {
    if(self.phase!=GDPhaseReady||self.pressurePending||![self buffLevel:GDBuffWildChoice]||color< -1||color>3)return NO;_selectedWildColor=color;_lastPreview=nil;return YES;
}
- (BOOL)toggleVerticalBlast { if(self.phase!=GDPhaseReady||self.pressurePending||![self buffLevel:GDBuffVerticalBlast])return NO;_verticalBlast=!_verticalBlast;_lastPreview=nil;return YES; }
- (NSInteger)energyThresholdForColor:(GDColor)color { return GDEnergyBase+(self.mode==GDGameModeEndless?(NSInteger)MIN(GDEnergyMaximum-GDEnergyBase,[_stats[GDSkillUseKey(color)] doubleValue]):0); }
- (NSArray<GDCell *> *)cells { return [[_board allValues] sortedArrayUsingComparator:^NSComparisonResult(GDCell *a,GDCell *b) { if(a.row!=b.row)return a.row<b.row?NSOrderedAscending:NSOrderedDescending;return a.column<b.column?NSOrderedAscending:(a.column>b.column?NSOrderedDescending:NSOrderedSame); }]; }
- (NSArray<NSNumber *> *)energy { return [_mutableEnergy copy]; }
- (GDObjective)objective { return _level?_level.objective:GDObjectiveClear; }
- (GDColor)objectiveColor { return _level?_level.objectiveColor:GDColorBlue; }
- (NSInteger)objectiveTarget { return _level?_level.target:0; }
- (NSInteger)totalWaves { return _level?_level.layouts.count:0; }
- (NSInteger)objectiveCurrent { if(!_level)return 0;switch(self.objective){case GDObjectiveClear:return _clearedWaves;case GDObjectiveCollect:return _collected;case GDObjectiveFall:return _fallenTotal;case GDObjectiveSurvive:return (NSInteger)floor(self.elapsed);} }
- (BOOL)won { return self.phase==GDPhaseWon; }
- (NSTimeInterval)pressureInterval { if(_level)return _level.pressureInterval;return fmax(6,12-floor(_difficultyTime/60)); }
- (NSInteger)columnsAtRow:(NSInteger)row { return ((row+self.rowPhase)&1)?17:18; }
- (BOOL)insideRow:(NSInteger)row column:(NSInteger)col { return row>=0&&col>=0&&col<[self columnsAtRow:row]&&row<16; }
- (CGPoint)centerOfCell:(GDCell *)cell { return [self centerOfCell:cell rowPhase:self.rowPhase]; }
- (CGPoint)centerOfCell:(GDCell *)cell rowPhase:(NSInteger)rowPhase { return CGPointMake(self.radius*(1+2*cell.column+((cell.row+rowPhase)&1)),self.radius+cell.row*self.radius*sqrt(3)); }
- (CGPoint)launcherPoint:(NSInteger)launcher { return CGPointMake(self.boardWidth*(launcher==0?.18:launcher==2?.82:.5),self.launchY); }
- (uint32_t)random { _rng^=_rng>>12;_rng^=_rng<<25;_rng^=_rng>>27;return (uint32_t)((_rng*2685821657736338717ULL)>>32); }
- (GDColor)legacyQueueColor { NSMutableIndexSet *set=[NSMutableIndexSet new]; for(GDCell *c in _board.allValues)[set addIndex:c.color];if(!set.count)return [self random]%4;NSUInteger pick=[self random]%set.count;NSUInteger color=set.firstIndex;while(pick--)color=[set indexGreaterThanIndex:color];return (GDColor)color; }
- (void)increment:(NSString *)key by:(NSInteger)value { _stats[key]=@([_stats[key] integerValue]+value); }
- (void)spendSkill:(GDColor)color { _mutableEnergy[color]=_economyEnabled?_overflow[color]:@0;if(_economyEnabled)_overflow[color]=@0;[self increment:GDSkillUseKey(color) by:1]; }
- (void)record:(NSString *)action { [_operations addObject:@{@"time":@(self.elapsed),@"action":action,@"score":@(self.score),@"revision":@(self.revision)}];if(_operations.count>12)[_operations removeObjectAtIndex:0]; }
- (instancetype)initWithSeed:(NSUInteger)seed {
    if((self=[super init])) { _runID=NSUUID.UUID.UUIDString;_seed=seed?:1;_rng=_seed;_board=[NSMutableDictionary new];_mutableEnergy=[@[@0,@0,@0,@0] mutableCopy];_stats=[NSMutableDictionary new];_operations=[NSMutableArray new];_heldColor=-1;_launcher=1;_wave=1;_pressureRemaining=12;_phase=GDPhaseReady;_bestScore=[[NSUserDefaults standardUserDefaults] integerForKey:@"GDPrototypeBestScore"];
        _economyEnabled=YES;_ammo=[@[@4,@4,@4,@4] mutableCopy];_materials=[@[@0,@0,@0,@0] mutableCopy];_overflow=[@[@0,@0,@0,@0] mutableCopy];_buffLevels=[NSMutableArray new];for(NSInteger i=0;i<GDBuffCount;i++)[_buffLevels addObject:@0];_shopOffers=@[];_secondHeldColor=-1;_selectedWildColor=-1;
        [self generateWave];_currentColor=[self queueColor];_nextColor=[self queueColor];
    } return self;
}
- (nullable instancetype)initWithLevelID:(NSInteger)levelID seed:(NSUInteger)seed {
    GDLevel *level=[GDLevelCatalog levelForID:levelID];if(!level)return nil;
    if((self=[self initWithSeed:seed?:level.seed])) { _level=level;_mode=GDGameModeLevel;_economyEnabled=NO;_levelID=levelID;_rng=_seed;[_board removeAllObjects];_mutableEnergy=[level.startingEnergy mutableCopy];self.pressureRemaining=level.pressureInterval;[self generateLevelWave];self.currentColor=[self queueColor];self.nextColor=[self queueColor]; }
    return self;
}
- (void)generateLevelWave {
    if(self.wave<1||self.wave>self.totalWaves)return;
    // Each authored wave starts with its own canonical honeycomb phase; the old board is empty.
    self.rowPhase=0;
    NSArray<NSString *> *rows=_level.layouts[self.wave-1];
    for(NSInteger r=0;r<(NSInteger)rows.count;r++)for(NSInteger c=0;c<(NSInteger)rows[r].length;c++){unichar ch=[rows[r] characterAtIndex:c];if(ch>='0'&&ch<='3'&&c<[self columnsAtRow:r]){GDCell *cell=[GDCell row:r column:c color:ch-'0'];_board[cell.key]=cell;}}
    self.revision++;
}
- (void)generateRow:(NSInteger)row gaps:(BOOL)gaps {
    for(NSInteger col=0;col<[self columnsAtRow:row];col++) {
        // An open notch and side entry on the lower edge make launcher changes useful.
        if(gaps&&row==self.initialRows-1&&(col==0||col==1||col==7||col==8||col==[self columnsAtRow:row]-1))continue;
        GDColor color=[self random]%4;
        GDCell *left=_board[GDKey(row,col-1)];
        if(left&&[self random]%4==0)color=left.color;
        GDCell *c=[GDCell row:row column:col color:color];_board[c.key]=c;
    }
}
- (void)generateWave { for(NSInteger row=0;row<self.initialRows;row++)[self generateRow:row gaps:YES];self.revision++; }
- (NSArray<GDCell *> *)adjacentPositions:(GDCell *)cell {
    NSMutableArray *result=[NSMutableArray new];CGPoint origin=[self centerOfCell:cell];
    for(NSInteger row=MAX(0,cell.row-1);row<=cell.row+1;row++)for(NSInteger col=MAX(0,cell.column-1);col<=cell.column+1;col++){
        if(![self insideRow:row column:col]||(row==cell.row&&col==cell.column))continue;
        GDCell *candidate=[GDCell row:row column:col color:cell.color];
        if(GDLength(GDSub([self centerOfCell:candidate],origin))<=2*self.radius+.01)[result addObject:candidate];
    }return result;
}
- (NSArray<GDCell *> *)neighborsOfCell:(GDCell *)cell { NSMutableArray *result=[NSMutableArray new];for(GDCell *p in [self adjacentPositions:cell])if(_board[p.key])[result addObject:_board[p.key]];return result; }
- (NSArray<GDCell *> *)blastTargetsAtCell:(GDCell *)cell {
    NSMutableArray *targets=[NSMutableArray new];CGPoint center=[self centerOfCell:cell];
    if(_verticalBlast&&[self buffLevel:GDBuffVerticalBlast]){for(NSInteger row=cell.row;row>=0&&row>cell.row-([self buffLevel:GDBuffVerticalBlast]+2);row--){GDCell *nearest=nil;CGFloat distance=CGFLOAT_MAX;for(GDCell *candidate in self.cells)if(candidate.row==row){CGFloat dx=fabs([self centerOfCell:candidate].x-center.x);if(dx<distance){distance=dx;nearest=candidate;}}if(nearest&&distance<=self.radius+.01)[targets addObject:[nearest copy]];}return targets;}
    // Two geometric honeycomb rings; empty cells do not block the blast.
    for(GDCell *candidate in self.cells)if(GDLength(GDSub([self centerOfCell:candidate],center))<=self.blastRadius+.01)[targets addObject:[candidate copy]];
    return targets;
}
- (NSArray<GDCell *> *)groupAt:(GDCell *)cell color:(GDColor)color {
    NSMutableArray *queue=[NSMutableArray arrayWithObject:cell],*group=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet setWithObject:cell.key];
    for(NSUInteger i=0;i<queue.count;i++){ GDCell *c=queue[i];[group addObject:c];for(GDCell *n in [self neighborsOfCell:c])if(n.color==color&&![seen containsObject:n.key]){[seen addObject:n.key];[queue addObject:n];} }return group;
}
- (NSArray<GDCell *> *)unsupported {
    NSMutableArray *queue=[NSMutableArray new];NSMutableSet *supported=[NSMutableSet new];
    for(GDCell *c in self.cells)if(c.row==0){[queue addObject:c];[supported addObject:c.key];}
    for(NSUInteger i=0;i<queue.count;i++)for(GDCell *n in [self neighborsOfCell:queue[i]])if(![supported containsObject:n.key]){[supported addObject:n.key];[queue addObject:n];}
    NSMutableArray *fallen=[NSMutableArray new];for(GDCell *c in self.cells)if(![supported containsObject:c.key])[fallen addObject:[c copy]];return fallen;
}
- (BOOL)selectLauncher:(NSInteger)launcher { if(self.phase!=GDPhaseReady||self.pressurePending||launcher<0||launcher>2)return NO;self.launcher=launcher;_lastPreview=nil;[self record:[NSString stringWithFormat:@"launcher:%ld",(long)launcher]];return YES; }
- (BOOL)hold { return [self holdSlot:0]; }
- (BOOL)holdSlot:(NSInteger)slot {
    if(self.phase!=GDPhaseReady||self.pressurePending||self.holdUsed||slot<0||slot>1||(slot==1&&![self buffLevel:GDBuffDoubleHold]))return NO;
    if(slot==1&&_secondHeldColor<0&&self.nextColor<0)return NO;
    if(slot==0&&self.heldColor<0&&self.nextColor<0)return NO;
    if(slot==1){NSInteger previous=self.currentColor;self.currentColor=(GDColor)_secondHeldColor;_secondHeldColor=previous;if(self.currentColor<0)[self refillQueue];self.holdUsed=YES;_lastPreview=nil;return previous>=0||self.currentColor>=0;}
    if(self.currentColor<0&&self.heldColor<0)return NO;
    if(self.heldColor<0){self.heldColor=self.currentColor;self.currentColor=self.nextColor;self.nextColor=[self queueColor];}
    else {GDColor old=self.currentColor;self.currentColor=(GDColor)self.heldColor;self.heldColor=old;}
    self.holdUsed=YES;_lastPreview=nil;[self increment:@"holdUses" by:1];[self record:@"hold"];return YES;
}
- (BOOL)segmentClearFrom:(CGPoint)a to:(CGPoint)b {
    for(GDCell *c in _board.allValues)if(GDSegmentDistance([self centerOfCell:c],a,b)<2*self.radius-.12)return NO;return YES;
}
// Follow the struck candy's exposed contact ring to the grid slot. A straight
// chord would incorrectly reject every oblique snap by entering the hit circle.
- (nullable NSArray<NSValue *> *)snapPathFrom:(CGPoint)contact to:(CGPoint)destination hit:(nullable GDCell *)hit {
    if(!hit)return [self segmentClearFrom:contact to:destination]?@[GDPoint(destination)]:nil;
    CGPoint center=[self centerOfCell:hit];
    CGFloat start=atan2(contact.y-center.y,contact.x-center.x),end=atan2(destination.y-center.y,destination.x-center.x);
    CGFloat sweep=atan2(sin(end-start),cos(end-start));
    NSInteger steps=MAX(2,(NSInteger)ceil(fabs(sweep)*16));NSMutableArray *path=[NSMutableArray new];
    for(NSInteger i=1;i<=steps;i++){
        CGFloat angle=start+sweep*i/steps;
        CGPoint p=CGPointMake(center.x+2*self.radius*cos(angle),center.y+2*self.radius*sin(angle));
        if(p.x<self.radius-.1||p.x>self.boardWidth-self.radius+.1||p.y<self.radius-.1)return nil;
        for(GDCell *obstacle in _board.allValues)if(![obstacle.key isEqual:hit.key]&&GDLength(GDSub(p,[self centerOfCell:obstacle]))<2*self.radius-.12)return nil;
        [path addObject:GDPoint(p)];
    }
    [path removeLastObject];[path addObject:GDPoint(destination)];return path;
}
- (nullable GDCell *)landingNear:(CGPoint)point direction:(CGPoint)direction hit:(nullable GDCell *)hit {
    NSMutableArray *candidates=[NSMutableArray new];
    if(hit) [candidates addObjectsFromArray:[self adjacentPositions:hit]];
    else for(NSInteger c=0;c<[self columnsAtRow:0];c++)[candidates addObject:[GDCell row:0 column:c color:self.currentColor]];
    [candidates sortUsingComparator:^NSComparisonResult(GDCell *a,GDCell *b) {
        CGFloat da=GDLength(GDSub([self centerOfCell:a],point)),db=GDLength(GDSub([self centerOfCell:b],point));
        if(fabs(da-db)>.001)return da<db?NSOrderedAscending:NSOrderedDescending;return [a.key compare:b.key options:NSNumericSearch];
    }];
    for(GDCell *c in candidates){
        if(_board[c.key])continue;CGPoint center=[self centerOfCell:c];
        if(GDLength(GDSub(center,point))>2*self.radius+.1)continue;
        if(hit&&GDDot(GDSub(center,[self centerOfCell:hit]),direction)>self.radius*.12)continue;
        if([self snapPathFrom:point to:center hit:hit])return c;
    }return nil;
}
- (GDShot *)previewToward:(CGPoint)target {
    GDShot *shot=[GDShot new];shot.boardRevision=self.revision;shot.blast=self.blastArmed;shot.resolvedColor=self.currentColor;
    if(self.phase!=GDPhaseReady||self.pressurePending){shot.reason=@"Busy";return shot;}
    if(_economyEnabled&&!shot.blast&&self.currentColor<0){shot.reason=@"Buy ammo or use Hold";return shot;}
    shot.wildcard=!shot.blast&&(self.wildRemaining>0||_bankWildReady);shot.verticalBlast=shot.blast&&_verticalBlast;
    CGPoint start=[self launcherPoint:self.launcher],d=GDSub(target,start);CGFloat length=GDLength(d);
    if(length<1||!isfinite(length)){shot.reason=@"Aim upward";return shot;}d=GDScale(d,1/length);
    if(d.y>-.22){shot.reason=@"Aim upward";return shot;}
    NSMutableArray *points=[NSMutableArray arrayWithObject:GDPoint(start)];CGPoint from=start;
    NSInteger maxBounces=[self buffLevel:GDBuffDoubleBounce]?2:1;
    for(NSInteger bounce=0;bounce<=maxBounces;bounce++){
        CGFloat top=(self.radius-from.y)/d.y;
        CGFloat wall=fabs(d.x)<.000001?CGFLOAT_MAX:((d.x>0?self.boardWidth-self.radius:self.radius)-from.x)/d.x;
        CGFloat limit=fmin(top,wall),first=CGFLOAT_MAX;GDCell *hit=nil;
        for(GDCell *c in self.cells){
            CGPoint v=GDSub(from,[self centerOfCell:c]);CGFloat b=GDDot(v,d),disc=b*b-(GDDot(v,v)-4*self.radius*self.radius);
            if(disc<0)continue;CGFloat t=-b-sqrt(fmax(0,disc));
            if(t>=-.001&&t<=limit+.001&&(t<first-.001||(fabs(t-first)<.001&&[c.key compare:hit.key?:@"" options:NSNumericSearch]==NSOrderedAscending))){first=fmax(0,t);hit=c;}
        }
        CGPoint contact=GDAdd(from,GDScale(d,hit?first:limit));[points addObject:GDPoint(contact)];
        if(hit||top<=wall+.001){
            shot.hitCell=[hit copy];
            if(shot.blast){shot.valid=hit!=nil;shot.reason=shot.valid?@"":@"Blast needs a target";if(hit)shot.expectedMatches=[self blastTargetsAtCell:hit];}
            else {
                GDCell *landing=[self landingNear:contact direction:d hit:hit];
                if(landing){
                    shot.valid=YES;shot.reason=@"";shot.landingRow=landing.row;shot.landingColumn=landing.column;[points addObjectsFromArray:[self snapPathFrom:contact to:[self centerOfCell:landing] hit:hit]];
                    NSArray *best=[self groupAt:landing color:self.currentColor];GDColor chosen=self.currentColor;
                    if(shot.wildcard&&[self neighborsOfCell:landing].count){ best=@[];for(GDColor color=GDColorBlue;color<=GDColorWhite;color++){NSArray *group=[self groupAt:landing color:color];if(group.count>best.count){best=group;chosen=color;}} }
                    if(shot.wildcard&&_selectedWildColor>=0&&[self buffLevel:GDBuffWildChoice]){for(GDCell *neighbor in [self neighborsOfCell:landing])if(neighbor.color==_selectedWildColor){chosen=(GDColor)_selectedWildColor;best=[self groupAt:landing color:chosen];break;}}
                    shot.resolvedColor=chosen;
                    if(best.count>=3){NSMutableArray *copies=[NSMutableArray new];for(GDCell *c in best){GDCell *copy=[c copy];if([copy.key isEqual:landing.key])copy.color=chosen;[copies addObject:copy];}shot.expectedMatches=copies;}
                }
            }
            break;
        }
        if(bounce==maxBounces){shot.reason=@"Bounce limit reached";break;}
        shot.bounced=YES;d.x=-d.x;from=contact;
    }
    shot.points=points;_lastPreview=shot;return shot;
}
- (BOOL)beginShot:(GDShot *)shot {
    if(self.phase!=GDPhaseReady||self.pressurePending||!shot.valid||shot!=_lastPreview||shot.boardRevision!=self.revision||shot.blast!=self.blastArmed)return NO;
    _flightCheckpoint=[self snapshot];_activeShot=shot;self.phase=GDPhaseFlying;
    if(shot.blast){if([_mutableEnergy[GDColorRed] integerValue]<[self energyThresholdForColor:GDColorRed]){self.phase=GDPhaseReady;_activeShot=nil;return NO;}[self spendSkill:GDColorRed];self.blastArmed=NO;}
    else {_chamberSpent=_economyEnabled;if(_bankWildReady&&self.wildRemaining==0)_bankWildReady=NO;if(self.wildRemaining>0){self.wildRemaining--;[self increment:@"wildShots" by:1];} [self increment:@"normalShots" by:1];[self increment:[NSString stringWithFormat:@"launcher%ldShots",(long)self.launcher] by:1];}
    if(shot.bounced)[self increment:@"bouncedShots" by:1];[self record:shot.blast?@"blast":@"shot"];return YES;
}
- (void)checkFailure:(GDEvent *)event {
    if(_economyEnabled&&[self buffLevel:GDBuffRescue]&&!_rescueUsed){for(GDCell *cell in self.cells)if([self centerOfCell:cell].y+self.radius>=self.dangerY-self.radius*sqrt(3)-.001){
        event.rescued=YES;event.rescuedCells=self.cells;[_board removeAllObjects];_rescueUsed=YES;self.wave++;[self resetWaveEconomy];[self generateWave];for(NSInteger i=0;i<3;i++)[self addRandomAmmo];[self refillQueue];self.pressureRemaining=self.pressureInterval;self.pressurePending=NO;self.revision++;event.newWave=YES;[self record:@"rescue"];break;
    }}
    for(GDCell *c in _board.allValues)if([self centerOfCell:c].y+self.radius>=self.dangerY-.001){self.phase=GDPhaseGameOver;event.gameOver=YES;self.blastArmed=NO;[self record:@"gameOver"];break;}
    if(self.mode==GDGameModeEndless&&self.score>self.bestScore){self.bestScore=self.score;[[NSUserDefaults standardUserDefaults] setInteger:self.bestScore forKey:@"GDPrototypeBestScore"];}
    if(event.gameOver){[[NSUserDefaults standardUserDefaults] setObject:[self diagnostics] forKey:@"GDPrototypeLastRun"];[self persistCompletion];}
}
- (void)persistCompletion {
    if(_completionRecorded)return;_completionRecorded=YES;
    if(self.mode==GDGameModeEndless) { [[[GDRunRecords alloc] initWithDefaults:NSUserDefaults.standardUserDefaults] recordRunID:self.runID score:self.score elapsed:self.elapsed seed:self.seed wave:self.wave]; }
    else if(self.won) { [[[GDProgressStore alloc] initWithDefaults:NSUserDefaults.standardUserDefaults] recordWinForLevel:self.levelID stars:self.stars score:self.score]; }
}
- (void)checkObjective:(GDEvent *)event {
    if(!_level||self.phase==GDPhaseGameOver||self.phase==GDPhaseWon||self.objectiveCurrent<self.objectiveTarget)return;
    NSInteger shots=[_stats[@"normalShots"] integerValue]+[_stats[@"redUses"] integerValue];
    BOOL shotsEfficient=shots<=_level.parShots,timeEfficient=self.objective==GDObjectiveSurvive?self.score>=_level.parScore:self.elapsed<=_level.parTime;
    self.stars=1+shotsEfficient+timeEfficient;self.phase=GDPhaseWon;self.pressurePending=NO;self.blastArmed=NO;event.won=YES;[self record:@"won"];[self persistCompletion];
}
- (GDEvent *)settle:(NSArray<GDCell *> *)direct source:(GDSource)source placed:(nullable GDCell *)placed {
    GDEvent *event=[GDEvent new];event.rowPhase=self.rowPhase;event.source=source;event.placed=[placed copy];NSMutableArray *unique=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(GDCell *c in direct)if(_board[c.key]&&![seen containsObject:c.key]){[seen addObject:c.key];[unique addObject:[_board[c.key] copy]];[_board removeObjectForKey:c.key];}
    event.removed=unique;event.fallen=[self unsupported];for(GDCell *c in event.fallen)[_board removeObjectForKey:c.key];
    event.points=event.removed.count*10+event.fallen.count*15;self.score+=event.points;if(_economyEnabled)_credits+=event.points;
    [self increment:@"directRemoved" by:event.removed.count];[self increment:@"fallenRemoved" by:event.fallen.count];
    if(_economyEnabled)for(GDCell *c in event.fallen){NSInteger total=_materials[c.color].integerValue+1;_materials[c.color]=@(total%3);_ammo[c.color]=@(_ammo[c.color].integerValue+total/3);}
    if(source==GDSourceNormal){for(GDCell *c in [event.removed arrayByAddingObjectsFromArray:event.fallen])[self addEnergy:1 color:c.color];
        if(_activeResolvingBounce&&event.removed.count){[self addEnergy:[self buffLevel:GDBuffBankEnergy] color:placed.color];NSInteger level=[self buffLevel:GDBuffBankWild];if(level&&++_bankMatches>=6-level){_bankMatches=0;_bankWildReady=YES;}}
    }
    _fallenTotal+=event.fallen.count;for(GDCell *c in [event.removed arrayByAddingObjectsFromArray:event.fallen])if(c.color==self.objectiveColor)_collected++;
    self.revision++;self.phase=GDPhaseResolving;
    if(_board.count==0){_clearedWaves++;[self increment:@"wavesCleared" by:1];}
    // All removals precede danger testing; a remaining touching cell loses even when the target is reached.
    [self checkFailure:event];[self checkObjective:event];
    if(!self.won&&self.phase!=GDPhaseGameOver&&_board.count==0){if(self.mode==GDGameModeEndless){self.wave++;if(_economyEnabled){[self resetWaveEconomy];_shopPending=YES;[self rollShop];self.pressureRemaining=self.pressureInterval;self.pressurePending=NO;}[self generateWave];event.newWave=YES;}else if(self.wave<self.totalWaves){self.wave++;[self generateLevelWave];event.newWave=YES;[self checkFailure:event];}}
    return event;
}
- (nullable GDEvent *)resolveShot {
    if(self.phase!=GDPhaseFlying||!_activeShot)return nil;GDShot *shot=_activeShot;_activeShot=nil;
    BOOL wild=shot.wildcard;_activeResolvingBounce=shot.bounced;
    GDEvent *event;
    if(shot.blast){GDCell *hit=_board[shot.hitCell.key];event=[self settle:hit?[self blastTargetsAtCell:hit]:@[] source:GDSourceBlast placed:nil];}
    else {
        GDCell *placed=[GDCell row:shot.landingRow column:shot.landingColumn color:shot.resolvedColor];
        if(_board[placed.key]){ // Mutation is locked during flight, so this guards an invalid integration only.
            self.phase=GDPhaseReady;_flightCheckpoint=nil;return nil;
        }
        _board[placed.key]=placed;NSArray *group=[self groupAt:placed color:placed.color];event=[self settle:group.count>=3?group:@[] source:wild?GDSourceWild:GDSourceNormal placed:placed];
        self.currentColor=self.nextColor;self.nextColor=(GDColor)-1;_chamberSpent=NO;[self refillQueue];self.holdUsed=NO;
    }
    _activeResolvingBounce=NO;_flightCheckpoint=nil;_lastPreview=nil;return event;
}
- (GDEvent *)pushRow {
    NSMutableDictionary *shifted=[NSMutableDictionary new];for(GDCell *c in self.cells){GDCell *copy=[c copy];copy.row++;shifted[copy.key]=copy;}_board=shifted;self.rowPhase=1-self.rowPhase;[self generateRow:0 gaps:NO];self.revision++;self.pressureRemaining+=self.pressureInterval;self.pressurePending=self.pressureRemaining<=0;self.phase=GDPhaseResolving;_lastPreview=nil;
    GDEvent *event=[GDEvent new];event.rowPhase=self.rowPhase;event.source=GDSourcePressure;event.pushed=YES;[self increment:@"pressureRows" by:1];[self record:@"pressure"];[self checkFailure:event];[self checkObjective:event];return event;
}
- (nullable GDEvent *)finishResolution { if(self.phase!=GDPhaseResolving)return nil;if(self.pressurePending)return [self pushRow];self.phase=_shopPending?GDPhaseShop:GDPhaseReady;if(_economyEnabled&&!_shopPending)[self prepareAmmo];if(_level&&self.objectiveCurrent>=self.objectiveTarget){GDEvent *event=[GDEvent new];[self checkFailure:event];[self checkObjective:event];return event;}return nil; }
- (nullable GDEvent *)advanceTime:(NSTimeInterval)delta {
    if(self.phase==GDPhasePaused||self.phase==GDPhaseShop||self.phase==GDPhaseGameOver||self.phase==GDPhaseWon||delta<0||!isfinite(delta))return nil;
    self.elapsed+=delta;NSTimeInterval frozen=MIN(delta,self.freezeRemaining);self.freezeRemaining=MAX(0,self.freezeRemaining-delta);if(frozen>0&&self.freezeRemaining==0&&_freezeBank){[self addEnergy:_freezeBank color:GDColorBlue];_freezeBank=0;}NSTimeInterval active=delta-frozen;_difficultyTime+=active;self.pressureRemaining-=active;
    if(self.pressureRemaining<=0)self.pressurePending=YES;
    if(self.pressurePending&&self.phase==GDPhaseReady)return [self pushRow];
    if(self.phase==GDPhaseReady&&_level&&self.objective==GDObjectiveSurvive&&self.objectiveCurrent>=self.objectiveTarget){GDEvent *event=[GDEvent new];[self checkFailure:event];[self checkObjective:event];return event;}
    return nil;
}
- (BOOL)activateSkill:(GDColor)color {
    if(self.phase!=GDPhaseReady||self.pressurePending||color<0||color>3)return NO;
    if(color==GDColorRed&&self.blastArmed){self.blastArmed=NO;_lastPreview=nil;return YES;}
    if([_mutableEnergy[color] integerValue]<[self energyThresholdForColor:color])return NO;
    if(color==GDColorRed){self.blastArmed=YES;_lastPreview=nil;return YES;}
    if(color==GDColorYellow)return NO;
    if((color==GDColorBlue&&self.freezeRemaining>0)||(color==GDColorWhite&&self.wildRemaining>0))return NO;
    [self spendSkill:color];
    if(color==GDColorBlue)self.freezeRemaining=GDFreezeDuration;
    else self.wildRemaining=GDWildShots;
    self.blastArmed=NO;_lastPreview=nil;[self record:color==GDColorBlue?@"freeze":@"wild"];return YES;
}
- (NSArray<GDCell *> *)yellowTargets { NSInteger deepest=-1;for(GDCell *c in self.cells)deepest=MAX(deepest,c.row);NSMutableArray *result=[NSMutableArray new];for(GDCell *c in self.cells)if(c.row>=deepest-GDYellowSweepRows+1)[result addObject:[c copy]];return result; }
- (nullable GDEvent *)activateYellow { if(self.phase!=GDPhaseReady||self.pressurePending||[_mutableEnergy[GDColorYellow] integerValue]<[self energyThresholdForColor:GDColorYellow]||!_board.count)return nil;[self spendSkill:GDColorYellow];self.blastArmed=NO;[self record:@"yellow"];GDEvent *event=[self settle:[self yellowTargets] source:GDSourceYellow placed:nil];if(self.phase!=GDPhaseGameOver&&self.phase!=GDPhaseWon)self.pressureRemaining+=2*[self buffLevel:GDBuffSweepDelay];return event; }
- (void)cancelBlast { if(self.phase==GDPhaseReady){self.blastArmed=NO;_lastPreview=nil;} }
- (void)pause { if(self.phase==GDPhasePaused||self.phase==GDPhaseGameOver||self.phase==GDPhaseWon)return;_phaseBeforePause=self.phase;self.phase=GDPhasePaused; }
- (void)resume { if(self.phase==GDPhasePaused)self.phase=_phaseBeforePause; }
- (NSDictionary *)encodedCell:(GDCell *)c { return @{@"r":@(c.row),@"c":@(c.column),@"color":@(c.color)}; }
- (NSDictionary *)diagnostics {
    NSMutableArray *board=[NSMutableArray new];for(GDCell *c in self.cells)[board addObject:[self encodedCell:c]];
    return @{@"version":@"endless-economy-v1",@"mode":@(self.mode),@"levelID":@(self.levelID),@"objectiveCurrent":@(self.objectiveCurrent),@"objectiveTarget":@(self.objectiveTarget),@"stars":@(self.stars),@"runID":self.runID,@"seed":@(self.seed),@"elapsed":@(self.elapsed),@"score":@(self.score),@"wave":@(self.wave),@"stats":[_stats copy],@"lastOperations":[_operations copy],@"board":board,@"energy":self.energy,@"phase":@(self.phase),@"economy":@(_economyEnabled),@"credits":@(_credits),@"ammo":self.ammoCounts,@"materials":self.materials,@"buffs":self.buffLevels,@"rescueUsed":@(_rescueUsed),@"shotsPerMinute":@(self.elapsed>0?[_stats[@"normalShots"] doubleValue]*60/self.elapsed:0)};
}
- (NSDictionary *)snapshot {
    GDPhase actual=self.phase==GDPhasePaused?_phaseBeforePause:self.phase;
    if(actual==GDPhaseFlying&&_flightCheckpoint)return _flightCheckpoint;
    NSMutableArray *board=[NSMutableArray new];for(GDCell *c in self.cells)[board addObject:[self encodedCell:c]];
    NSMutableDictionary *snapshot=[@{@"format":@3,@"mode":@(self.mode),@"levelID":@(self.levelID),@"runID":self.runID,@"clearedWaves":@(_clearedWaves),@"collected":@(_collected),@"fallenTotal":@(_fallenTotal),@"won":@(actual==GDPhaseWon),@"stars":@(self.stars),@"completionRecorded":@(_completionRecorded),@"seed":@(self.seed),@"rng":@(_rng),@"board":board,@"rowPhase":@(self.rowPhase),@"revision":@(self.revision),@"current":@(self.currentColor),@"next":@(self.nextColor),@"held":@(self.heldColor),@"holdUsed":@(self.holdUsed),@"launcher":@(self.launcher),@"wild":@(self.wildRemaining),@"score":@(self.score),@"wave":@(self.wave),@"pressure":@(self.pressureRemaining),@"pending":@(self.pressurePending),@"freeze":@(self.freezeRemaining),@"elapsed":@(self.elapsed),@"difficulty":@(_difficultyTime),@"energy":self.energy,@"stats":[_stats copy],@"operations":[_operations copy],@"gameOver":@(actual==GDPhaseGameOver)} mutableCopy];
    snapshot[@"economy"]=@{@"enabled":@(_economyEnabled),@"credits":@(_credits),@"ammo":[_ammo copy],@"materials":self.materials,@"buffs":self.buffLevels,@"overflow":self.overflowEnergy,@"secondHeld":@(_secondHeldColor),@"wildColor":@(_selectedWildColor),@"recolors":@(_recolorsUsed),@"purchases":@(_ammoPurchases),@"bankMatches":@(_bankMatches),@"bankWild":@(_bankWildReady),@"iceBank":@(_freezeBank),@"rescueUsed":@(_rescueUsed),@"vertical":@(_verticalBlast),@"emergencyUsed":@(_emergencyUsed),@"shopPending":@(_shopPending),@"offers":_shopOffers};return snapshot;
}
- (BOOL)restoreEconomy:(NSDictionary *)data {
    if(![data isKindOfClass:NSDictionary.class])return NO;
    NSArray *numeric=@[@"enabled",@"credits",@"secondHeld",@"wildColor",@"recolors",@"purchases",@"bankMatches",@"bankWild",@"iceBank",@"rescueUsed",@"vertical",@"emergencyUsed",@"shopPending"];
    for(NSString *key in numeric){id n=data[key];if(![n isKindOfClass:NSNumber.class]||!isfinite([n doubleValue])||floor([n doubleValue])!=[n doubleValue]||[n doubleValue]< -1||[n doubleValue]>100000000)return NO;}
    for(NSString *key in @[@"enabled",@"bankWild",@"rescueUsed",@"vertical",@"emergencyUsed",@"shopPending"])if([data[key] integerValue]<0||[data[key] integerValue]>1)return NO;
    for(NSString *key in @[@"ammo",@"materials",@"buffs",@"overflow",@"offers"]){if(![data[key] isKindOfClass:NSArray.class])return NO;for(id n in data[key])if(![n isKindOfClass:NSNumber.class]||!isfinite([n doubleValue])||floor([n doubleValue])!=[n doubleValue]||[n doubleValue]<0||[n doubleValue]>1000000)return NO;}
    if([data[@"ammo"] count]!=4||[data[@"materials"] count]!=4||[data[@"overflow"] count]!=4||[data[@"buffs"] count]!=GDBuffCount||[data[@"offers"] count]>3)return NO;
    _economyEnabled=[data[@"enabled"] boolValue];_credits=[data[@"credits"] integerValue];_ammo=[data[@"ammo"] mutableCopy];_materials=[data[@"materials"] mutableCopy];_buffLevels=[data[@"buffs"] mutableCopy];_overflow=[data[@"overflow"] mutableCopy];
    for(GDBuff b=0;b<GDBuffCount;b++)if(_buffLevels[b].integerValue>[GDBuffCatalog maximumLevel:b])return NO;
    NSInteger reserve=[self buffLevel:GDBuffOverflow];for(NSInteger c=0;c<4;c++)if(_materials[c].integerValue>2||_overflow[c].integerValue>(reserve?[@[@5,@8,@10][reserve-1] integerValue]:0))return NO;
    _secondHeldColor=[data[@"secondHeld"] integerValue];_selectedWildColor=[data[@"wildColor"] integerValue];_recolorsUsed=[data[@"recolors"] integerValue];_ammoPurchases=[data[@"purchases"] integerValue];_bankMatches=[data[@"bankMatches"] integerValue];_bankWildReady=[data[@"bankWild"] boolValue];_freezeBank=[data[@"iceBank"] integerValue];_rescueUsed=[data[@"rescueUsed"] boolValue];_verticalBlast=[data[@"vertical"] boolValue];_emergencyUsed=[data[@"emergencyUsed"] boolValue];_shopPending=[data[@"shopPending"] boolValue];_shopOffers=[data[@"offers"] copy];
    if(_credits<0||_recolorsUsed<0||_recolorsUsed>[self buffLevel:GDBuffRecolor]||_ammoPurchases<0||_bankMatches<0||_bankMatches>4||_freezeBank<0||_freezeBank>8||_secondHeldColor< -1||_secondHeldColor>3||_selectedWildColor< -1||_selectedWildColor>3)return NO;
    if((_secondHeldColor>=0&&![self buffLevel:GDBuffDoubleHold])||(_verticalBlast&&![self buffLevel:GDBuffVerticalBlast])||(_rescueUsed&&![self buffLevel:GDBuffRescue]))return NO;
    NSInteger iceLevel=[self buffLevel:GDBuffIceReserve],bankLevel=[self buffLevel:GDBuffBankWild];
    if((_selectedWildColor>=0&&![self buffLevel:GDBuffWildChoice])||_freezeBank>(iceLevel?[@[@3,@5,@8][iceLevel-1] integerValue]:0)||(_bankWildReady&&!bankLevel)||_bankMatches>=(bankLevel?6-bankLevel:1)||(_emergencyUsed&&![self buffLevel:GDBuffEmergency])||(_shopPending&&!_economyEnabled))return NO;
    NSMutableSet *seen=[NSMutableSet new];for(NSNumber *offer in _shopOffers){if(offer.integerValue>=GDBuffCount||[seen containsObject:offer]||![self nextBuffPrice:offer.integerValue]||(offer.integerValue==GDBuffRescue&&_rescueUsed))return NO;[seen addObject:offer];}if(!_shopPending&&_shopOffers.count)return NO;
    return YES;
}
- (nullable instancetype)initWithSnapshot:(NSDictionary *)s {
    if(![s isKindOfClass:NSDictionary.class])return nil;
    for(NSString *key in @[@"format",@"seed",@"rng",@"rowPhase",@"revision",@"current",@"next",@"held",@"holdUsed",@"launcher",@"wild",@"score",@"wave",@"pressure",@"pending",@"freeze",@"elapsed",@"difficulty",@"gameOver"])if(![s[key] isKindOfClass:NSNumber.class])return nil;
    if([s[@"format"] integerValue]>=2){for(NSString *key in @[@"mode",@"levelID",@"clearedWaves",@"collected",@"fallenTotal",@"won",@"stars",@"completionRecorded"])if(![s[key] isKindOfClass:NSNumber.class])return nil;if(![s[@"runID"] isKindOfClass:NSString.class]||![s[@"runID"] length])return nil;}
    if(([s[@"format"] integerValue]<1||[s[@"format"] integerValue]>3)||![s[@"board"] isKindOfClass:NSArray.class]||![s[@"energy"] isKindOfClass:NSArray.class]||[s[@"energy"] count]!=4)return nil;
    NSInteger mode=[s[@"format"] integerValue]==1?GDGameModeEndless:[s[@"mode"] integerValue];if(mode!=GDGameModeEndless&&mode!=GDGameModeLevel)return nil;
    if(mode==GDGameModeLevel){if(!(self=[self initWithLevelID:[s[@"levelID"] integerValue] seed:[s[@"seed"] unsignedIntegerValue]]))return nil;}else if(!(self=[self initWithSeed:[s[@"seed"] unsignedIntegerValue]]))return nil;
    _economyEnabled=NO;
    if([s[@"format"] integerValue]==3&&! [self restoreEconomy:s[@"economy"]])return nil;
    if(mode==GDGameModeLevel&&_economyEnabled)return nil;
    if([s[@"runID"] isKindOfClass:NSString.class]&&[s[@"runID"] length])self.runID=s[@"runID"];
    _clearedWaves=[s[@"clearedWaves"] integerValue];_collected=[s[@"collected"] integerValue];_fallenTotal=[s[@"fallenTotal"] integerValue];self.stars=[s[@"stars"] integerValue];_completionRecorded=[s[@"completionRecorded"] boolValue];
    if(_clearedWaves<0||_collected<0||_fallenTotal<0||self.stars<0||self.stars>3)return nil;
    _board=[NSMutableDictionary new];self.rowPhase=[s[@"rowPhase"] integerValue];if(self.rowPhase<0||self.rowPhase>1)return nil;
    for(NSDictionary *data in s[@"board"]){if(![data isKindOfClass:NSDictionary.class]||![data[@"r"] isKindOfClass:NSNumber.class]||![data[@"c"] isKindOfClass:NSNumber.class]||![data[@"color"] isKindOfClass:NSNumber.class])return nil;NSInteger row=[data[@"r"] integerValue],col=[data[@"c"] integerValue],color=[data[@"color"] integerValue];if(![self insideRow:row column:col]||color<0||color>3||_board[GDKey(row,col)])return nil;GDCell *c=[GDCell row:row column:col color:color];_board[c.key]=c;}
    _rng=[s[@"rng"] unsignedLongLongValue];if(!_rng)return nil;
    self.currentColor=[s[@"current"] integerValue];self.nextColor=[s[@"next"] integerValue];self.heldColor=[s[@"held"] integerValue];self.launcher=[s[@"launcher"] integerValue];self.wildRemaining=[s[@"wild"] integerValue];
    if(self.currentColor<(_economyEnabled?-1:0)||self.currentColor>3||self.nextColor<(_economyEnabled?-1:0)||self.nextColor>3||self.heldColor< -1||self.heldColor>3||self.launcher<0||self.launcher>2||self.wildRemaining<0||self.wildRemaining>GDWildShots)return nil;
    id stats=s[@"stats"];if(stats&&![stats isKindOfClass:NSDictionary.class])return nil;for(id key in stats){id value=stats[key];if(![key isKindOfClass:NSString.class]||![value isKindOfClass:NSNumber.class]||[value doubleValue]<0||!isfinite([value doubleValue]))return nil;}
    _stats=stats?[stats mutableCopy]:[NSMutableDictionary new];
    _mutableEnergy=[NSMutableArray new];for(id energy in s[@"energy"]){if(![energy isKindOfClass:NSNumber.class]||[energy integerValue]<0||[energy integerValue]>[self energyThresholdForColor:(GDColor)_mutableEnergy.count])return nil;[_mutableEnergy addObject:energy];}
    self.revision=[s[@"revision"] integerValue];self.holdUsed=[s[@"holdUsed"] boolValue];self.score=[s[@"score"] integerValue];self.wave=[s[@"wave"] integerValue];self.pressureRemaining=[s[@"pressure"] doubleValue];self.pressurePending=[s[@"pending"] boolValue];self.freezeRemaining=[s[@"freeze"] doubleValue];self.elapsed=[s[@"elapsed"] doubleValue];_difficultyTime=[s[@"difficulty"] doubleValue];
    if(!isfinite(self.pressureRemaining)||!isfinite(self.freezeRemaining)||!isfinite(self.elapsed)||!isfinite(_difficultyTime)||self.freezeRemaining<0||self.freezeRemaining>GDFreezeDuration||self.elapsed<0||_difficultyTime<0||self.score<0||self.wave<1||_credits>self.score)return nil;
    if(_freezeBank&&self.freezeRemaining==0)return nil;
    // Restored operations are eventually included in persisted diagnostics.
    // Reject non-property-list values here rather than throwing on game over.
    id operations=s[@"operations"];if(operations&&(![operations isKindOfClass:NSArray.class]||![NSPropertyListSerialization propertyList:operations isValidForFormat:NSPropertyListBinaryFormat_v1_0]))return nil;
    _operations=[s[@"operations"] isKindOfClass:NSArray.class]?[s[@"operations"] mutableCopy]:[NSMutableArray new];
    if(self.mode==GDGameModeLevel&&(self.wave>self.totalWaves||(self.objective==GDObjectiveClear&&_clearedWaves>self.totalWaves)))return nil;
    if([s[@"won"] boolValue]&&(self.mode!=GDGameModeLevel||self.stars<1||self.objectiveCurrent<self.objectiveTarget))return nil;
    self.phase=[s[@"won"] boolValue]?GDPhaseWon:[s[@"gameOver"] boolValue]?GDPhaseGameOver:GDPhasePaused;_phaseBeforePause=_shopPending?GDPhaseShop:GDPhaseReady;return self;
}
#if DEBUG || GD_CORE_TESTS
- (void)loadFixture:(NSArray<GDCell *> *)cells phase:(NSInteger)phase current:(GDColor)current next:(GDColor)next { _board=[NSMutableDictionary new];self.rowPhase=phase;for(GDCell *c in cells)_board[c.key]=[c copy];self.currentColor=current;self.nextColor=next;self.phase=GDPhaseReady;self.revision++;_activeShot=nil;_lastPreview=nil;self.pressurePending=NO;self.pressureRemaining=12; }
- (void)setFixtureEconomyCredits:(NSInteger)credits ammo:(NSArray<NSNumber *> *)ammo buffs:(NSArray<NSNumber *> *)buffs { _credits=credits;self.score=MAX(self.score,credits);if(ammo.count==4)_ammo=[ammo mutableCopy];if(buffs.count==GDBuffCount)_buffLevels=[buffs mutableCopy]; }
- (void)setFixtureEnergy:(NSArray<NSNumber *> *)energy { if(energy.count==4)_mutableEnergy=[energy mutableCopy]; }
#endif
@end
