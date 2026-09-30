#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GDColor) { GDColorBlue, GDColorRed, GDColorYellow, GDColorWhite };
typedef NS_ENUM(NSInteger, GDPhase) { GDPhaseReady, GDPhaseFlying, GDPhaseResolving, GDPhasePaused, GDPhaseGameOver, GDPhaseWon };
typedef NS_ENUM(NSInteger, GDGameMode) { GDGameModeEndless, GDGameModeLevel };
typedef NS_ENUM(NSInteger, GDObjective) { GDObjectiveClear, GDObjectiveCollect, GDObjectiveFall, GDObjectiveSurvive };
typedef NS_ENUM(NSInteger, GDSource) { GDSourceNormal, GDSourceWild, GDSourceBlast, GDSourceYellow, GDSourcePressure };

@interface GDCell : NSObject <NSCopying>
@property(nonatomic) NSInteger row, column;
@property(nonatomic) GDColor color;
@property(nonatomic, readonly) NSString *key;
+ (instancetype)row:(NSInteger)row column:(NSInteger)column color:(GDColor)color;
@end

@interface GDShot : NSObject
@property(nonatomic) BOOL valid, blast, bounced;
@property(nonatomic) NSInteger boardRevision, landingRow, landingColumn;
@property(nonatomic) GDColor resolvedColor;
@property(nonatomic, copy) NSArray<NSValue *> *points; // CGPoint, board-local x right / y down
@property(nonatomic, nullable) GDCell *hitCell;
@property(nonatomic, copy) NSArray<GDCell *> *expectedMatches;
@property(nonatomic, copy) NSString *reason;
@end

@interface GDEvent : NSObject
@property(nonatomic) GDSource source;
@property(nonatomic, copy) NSArray<GDCell *> *removed, *fallen;
@property(nonatomic, nullable) GDCell *placed;
@property(nonatomic) BOOL pushed, newWave, gameOver, won;
@property(nonatomic) NSInteger points, rowPhase; // phase used by removed/fallen coordinates before any new wave
@end

@interface GDEngine : NSObject
@property(nonatomic, readonly) GDGameMode mode;
@property(nonatomic, readonly) NSInteger levelID, objectiveCurrent, objectiveTarget, stars, totalWaves;
@property(nonatomic, readonly) GDObjective objective;
@property(nonatomic, readonly) GDColor objectiveColor;
@property(nonatomic, readonly) NSString *runID;
@property(nonatomic, readonly) BOOL won;
@property(nonatomic, readonly) CGFloat radius, boardWidth, dangerY, launchY;
@property(nonatomic, readonly) NSInteger longColumns, initialRows, rowPhase, revision;
@property(nonatomic, readonly) NSArray<GDCell *> *cells;
@property(nonatomic, readonly) GDPhase phase;
@property(nonatomic, readonly) GDColor currentColor, nextColor;
@property(nonatomic, readonly) NSInteger heldColor; // -1 means empty
@property(nonatomic, readonly) BOOL holdUsed, blastArmed, pressurePending;
@property(nonatomic, readonly) NSInteger launcher, wildRemaining, score, bestScore, wave;
@property(nonatomic, readonly) NSUInteger seed;
@property(nonatomic, readonly) NSTimeInterval pressureRemaining, pressureInterval, freezeRemaining, elapsed;
@property(nonatomic, readonly) NSArray<NSNumber *> *energy;
@property(nonatomic, readonly) NSInteger energyThreshold;
- (nullable instancetype)initWithLevelID:(NSInteger)levelID seed:(NSUInteger)seed;
- (instancetype)initWithSeed:(NSUInteger)seed;
- (nullable instancetype)initWithSnapshot:(NSDictionary *)snapshot;
- (CGPoint)centerOfCell:(GDCell *)cell;
- (CGPoint)centerOfCell:(GDCell *)cell rowPhase:(NSInteger)rowPhase;
- (CGPoint)launcherPoint:(NSInteger)launcher;
- (NSArray<GDCell *> *)neighborsOfCell:(GDCell *)cell;
- (BOOL)selectLauncher:(NSInteger)launcher;
- (BOOL)hold;
- (GDShot *)previewToward:(CGPoint)target; // shared authoritative shot, no mutation
- (BOOL)beginShot:(GDShot *)shot; // rejects stale preview; spends blast / wildcard only on success
- (nullable GDEvent *)resolveShot; // call at visual flight end; resolves exactly once
- (nullable GDEvent *)finishResolution; // after event animation; executes overdue pressure before unlocking
- (nullable GDEvent *)advanceTime:(NSTimeInterval)delta; // may return a pressure event; continue while flying/animating
- (BOOL)activateSkill:(GDColor)color; // blue/white immediate; red arms/cancels without spending
- (nullable GDEvent *)activateYellow;
- (NSArray<GDCell *> *)yellowTargets;
- (void)cancelBlast;
- (void)pause;
- (void)resume;
- (NSDictionary *)snapshot; // persisted continuation (restores paused), deterministic RNG + diagnostics
- (NSDictionary *)diagnostics;
// Deterministic fixtures for core validation and acceptance; production UI never alters cells.
#if DEBUG || GD_CORE_TESTS
- (void)loadFixture:(NSArray<GDCell *> *)cells phase:(NSInteger)phase current:(GDColor)current next:(GDColor)next;
- (void)setFixtureEnergy:(NSArray<NSNumber *> *)energy;
#endif
@end
NS_ASSUME_NONNULL_END
