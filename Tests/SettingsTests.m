#import <Foundation/Foundation.h>
#import "GDSettings.h"
static void Check(BOOL pass, NSString *message) {
    if(!pass) { fprintf(stderr,"FAIL: %s\n",message.UTF8String); exit(1); }
}
int main(void) { @autoreleasepool {
    NSString *suite=[@"GummySettingsTests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
    GDSettings *settings=[[GDSettings alloc] initWithDefaults:defaults];
    Check(settings.aimGuideEnabled&&settings.hapticsEnabled&&settings.soundEffectsEnabled,@"new install defaults enabled");
    NSDictionary *run=@{@"score":@120,@"board":@[@1,@2]};
    [defaults setObject:run forKey:@"GummyRunSnapshot"];
    settings.aimGuideEnabled=NO; settings.hapticsEnabled=NO; settings.soundEffectsEnabled=NO;
    GDSettings *reloaded=[[GDSettings alloc] initWithDefaults:[[NSUserDefaults alloc] initWithSuiteName:suite]];
    Check(!reloaded.aimGuideEnabled&&!reloaded.hapticsEnabled&&!reloaded.soundEffectsEnabled,@"disabled settings survive new settings/defaults instances");
    Check([run isEqual:[defaults objectForKey:@"GummyRunSnapshot"]],@"settings do not alter current run");
    reloaded.aimGuideEnabled=YES; reloaded.soundEffectsEnabled=YES;
    Check(settings.aimGuideEnabled&&settings.soundEffectsEnabled&&!settings.hapticsEnabled,@"changes apply to existing instance immediately and independently");
    [defaults removePersistentDomainForName:suite];
    NSLog(@"PASS: 4 persistent settings checks");
} }
