#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Engine completion, best scores and diagnostics use standardUserDefaults.
// CLI tests must isolate all of them, including winning search clones and exits
// caused by failed assertions. This file is linked only by the test scripts.
static NSUserDefaults *isolatedDefaults;
static NSString *isolatedSuite;
static id TestStandardDefaults(id self, SEL cmd){return isolatedDefaults;}
static void RemoveTestDefaults(void){@autoreleasepool{[isolatedDefaults removePersistentDomainForName:isolatedSuite];}}
@interface GDTestDefaults : NSObject
@end
@implementation GDTestDefaults
+ (void)load {
    @autoreleasepool {
        isolatedSuite=[@"GDCoreTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        isolatedDefaults=[[NSUserDefaults alloc]initWithSuiteName:isolatedSuite];
        method_setImplementation(class_getClassMethod(NSUserDefaults.class,@selector(standardUserDefaults)),(IMP)TestStandardDefaults);
        atexit(RemoveTestDefaults);
    }
}
@end
