#import "GDRunRecords.h"
#import <math.h>
@interface GDRunRecords ()
@property(nonatomic) NSUserDefaults *defaults;
@end
@implementation GDRunRecords
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults { if((self=[super init]))_defaults=defaults;return self; }
- (NSDictionary *)data { id d=[self.defaults objectForKey:@"GDEndlessRecords"];return [d isKindOfClass:NSDictionary.class]&&[d[@"format"] isKindOfClass:NSNumber.class]&&[d[@"format"] integerValue]==1?d:@{}; }
- (NSArray<NSDictionary *> *)records {
    NSMutableArray *valid=[NSMutableArray new];id records=self.data[@"records"];
    if([records isKindOfClass:NSArray.class])for(id r in records)if([r isKindOfClass:NSDictionary.class]&&[r[@"runID"] isKindOfClass:NSString.class]&&[r[@"score"] isKindOfClass:NSNumber.class]&&[r[@"elapsed"] isKindOfClass:NSNumber.class]&&[r[@"date"] isKindOfClass:NSNumber.class]&&[r[@"seed"] isKindOfClass:NSNumber.class]&&[r[@"wave"] isKindOfClass:NSNumber.class]&&[r[@"score"] integerValue]>=0&&[r[@"elapsed"] doubleValue]>=0&&isfinite([r[@"elapsed"] doubleValue])&&isfinite([r[@"date"] doubleValue]))[valid addObject:r];
    [valid sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSInteger x=[a[@"score"] integerValue],y=[b[@"score"] integerValue];if(x!=y)return x>y?NSOrderedAscending:NSOrderedDescending;NSComparisonResult date=[a[@"date"] compare:b[@"date"]];return date==NSOrderedSame?[a[@"runID"] compare:b[@"runID"]]:date;}];if(valid.count>50)[valid removeObjectsInRange:NSMakeRange(50,valid.count-50)];return valid;
}
- (BOOL)recordRunID:(NSString *)runID score:(NSInteger)score elapsed:(NSTimeInterval)elapsed seed:(NSUInteger)seed wave:(NSInteger)wave {
    if(!runID.length||score<0||elapsed<0||!isfinite(elapsed)||wave<1)return NO;
    @synchronized(self.defaults) { NSMutableArray *seen=[self.data[@"seen"] isKindOfClass:NSArray.class]?[self.data[@"seen"] mutableCopy]:[NSMutableArray new];if([seen containsObject:runID])return NO;for(NSDictionary *r in self.records)if([r[@"runID"] isEqual:runID])return NO;
        NSMutableArray *records=[self.records mutableCopy];[records addObject:@{@"runID":runID,@"score":@(score),@"elapsed":@(elapsed),@"date":@([NSDate.date timeIntervalSince1970]),@"seed":@(seed),@"wave":@(wave)}];[seen addObject:runID];if(seen.count>512)[seen removeObjectsInRange:NSMakeRange(0,seen.count-512)];[records sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSInteger x=[a[@"score"] integerValue],y=[b[@"score"] integerValue];if(x!=y)return x>y?NSOrderedAscending:NSOrderedDescending;NSComparisonResult date=[a[@"date"] compare:b[@"date"]];return date==NSOrderedSame?[a[@"runID"] compare:b[@"runID"]]:date;}];if(records.count>50)[records removeObjectsInRange:NSMakeRange(50,records.count-50)];[self.defaults setObject:@{@"format":@1,@"records":records,@"seen":seen} forKey:@"GDEndlessRecords"];return YES;
    }
}
- (NSInteger)rankForRunID:(NSString *)runID { NSInteger rank=0;for(NSDictionary *r in self.records){rank++;if([r[@"runID"] isEqual:runID])return rank;}return 0; }
@end
