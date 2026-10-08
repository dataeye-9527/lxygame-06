#import <Foundation/Foundation.h>
#import "GDSettings.h"
static void Check(BOOL pass, NSString *message) {
    if(!pass) { fprintf(stderr,"FAIL: %s\n",message.UTF8String); exit(1); }
}
int main(void) { @autoreleasepool {
    NSString *suite=[@"GummySettingsTests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
    GDSettings *settings=[[GDSettings alloc] initWithDefaults:defaults];
    Check(settings.aimGuideEnabled&&settings.hapticsEnabled&&settings.soundEffectsEnabled&&settings.musicEnabled,@"new install defaults enabled including music for existing installs");
    NSDictionary *run=@{@"score":@120,@"board":@[@1,@2]};
    [defaults setObject:run forKey:@"GummyRunSnapshot"];
    settings.aimGuideEnabled=NO; settings.hapticsEnabled=NO; settings.soundEffectsEnabled=NO; settings.musicEnabled=NO;
    GDSettings *reloaded=[[GDSettings alloc] initWithDefaults:[[NSUserDefaults alloc] initWithSuiteName:suite]];
    Check(!reloaded.aimGuideEnabled&&!reloaded.hapticsEnabled&&!reloaded.soundEffectsEnabled&&!reloaded.musicEnabled,@"disabled settings survive new settings/defaults instances");
    Check([run isEqual:[defaults objectForKey:@"GummyRunSnapshot"]],@"settings do not alter current run");
    reloaded.aimGuideEnabled=YES; reloaded.soundEffectsEnabled=YES;
    Check(settings.aimGuideEnabled&&settings.soundEffectsEnabled&&!settings.hapticsEnabled&&!settings.musicEnabled,@"effects can be enabled while music remains disabled");
    reloaded.musicEnabled=YES; reloaded.soundEffectsEnabled=NO;
    Check(settings.musicEnabled&&!settings.soundEffectsEnabled&&!settings.hapticsEnabled,@"music can be enabled while effects remain disabled");
    [defaults removePersistentDomainForName:suite];
    NSLog(@"PASS: 5 persistent settings checks");
} }
