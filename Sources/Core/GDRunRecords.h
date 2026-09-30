#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Immutable dictionaries: runID, score, elapsed, date (Unix seconds), seed, wave.
// Highest score first; ties retain earliest completion. Maximum 50 records.
@interface GDRunRecords : NSObject
@property(nonatomic, readonly) NSArray<NSDictionary *> *records;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (BOOL)recordRunID:(NSString *)runID score:(NSInteger)score elapsed:(NSTimeInterval)elapsed seed:(NSUInteger)seed wave:(NSInteger)wave;
- (NSInteger)rankForRunID:(NSString *)runID; // 1-based, 0 if outside retained board
@end
NS_ASSUME_NONNULL_END
