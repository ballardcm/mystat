// Runs Sparkle against disposable bundles and localhost feeds; never changes MyStat's installation.
#import <AppKit/AppKit.h>
#import <Sparkle/Sparkle.h>

@interface TestDriver : NSObject <SPUUserDriver, SPUUpdaterDelegate>
@property NSString *feed;
@property NSString *expected;
@property SPUUpdater *updater;
@end
@implementation TestDriver
- (void)finish:(NSString *)result {
    if ([result isEqualToString:self.expected]) { printf("PASS: %s\n", result.UTF8String); exit(0); }
    fprintf(stderr, "Expected %s, got %s\n", self.expected.UTF8String, result.UTF8String); exit(1);
}
- (void)updater:(SPUUpdater *)updater didFinishUpdateCycleForUpdateCheck:(SPUUpdateCheck)check error:(NSError *)error {
    if ([self.expected isEqualToString:@"background"] && check == SPUUpdateCheckUpdatesInBackground) {
        if (error != nil && error.code != SUNoUpdateError) { [self finish:@"background-error"]; }
        updater.automaticallyChecksForUpdates = NO;
        [self finish:@"background"];
    }
}
- (NSString *)feedURLStringForUpdater:(SPUUpdater *)updater { return self.feed; }
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request reply:(void (^)(SUUpdatePermissionResponse *))reply { [self finish:@"unexpected-permission"]; }
- (void)showUserInitiatedUpdateCheckWithCancellation:(void (^)(void))cancellation {}
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply {
    if ([self.expected isEqualToString:@"defer"]) { reply(SPUUserUpdateChoiceDismiss); [self finish:@"defer"]; }
    else { reply(SPUUserUpdateChoiceInstall); }
}
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data {}
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error { [self finish:@"notes-error"]; }
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))ack { ack(); [self finish:@"no-update"]; }
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))ack {
    fprintf(stderr, "Sparkle rejected update (%ld): %s\n", (long)error.code, error.localizedDescription.UTF8String);
    // Assert the intended failure class; a broken fixture must not masquerade as signature coverage.
    NSInteger expectedCode = [self.feed containsString:@"tampered.xml"] ? 1000 :
        [self.feed containsString:@"bad-archive.xml"] ? 4005 : 2001;
    if (error.code != expectedCode) { [self finish:@"wrong-error"]; }
    ack(); [self finish:@"error"];
}
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancellation {
    if ([self.expected isEqualToString:@"cancel"]) { cancellation(); [self finish:@"cancel"]; }
}
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length {}
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {}
- (void)showDownloadDidStartExtractingUpdate {}
- (void)showExtractionReceivedProgress:(double)progress {}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply { reply(SPUUserUpdateChoiceInstall); }
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated retryTerminatingApplication:(void (^)(void))retry {}
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))ack { ack(); [self finish:@"installed"]; }
- (void)dismissUpdateInstallation {}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 4) return 2;
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyProhibited];
        TestDriver *driver = [TestDriver new];
        driver.feed = @(argv[2]); driver.expected = @(argv[3]);
        NSBundle *host = [NSBundle bundleWithPath:@(argv[1])];
        driver.updater = [[SPUUpdater alloc] initWithHostBundle:host applicationBundle:host userDriver:driver delegate:driver];
        NSError *error = nil;
        if (![driver.updater startUpdater:&error]) { fprintf(stderr, "%s\n", error.description.UTF8String); return 1; }
        if ([driver.expected isEqualToString:@"disabled"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [driver finish:@"disabled"]; });
        } else if ([driver.expected isEqualToString:@"background"]) {
            dispatch_async(dispatch_get_main_queue(), ^{ driver.updater.automaticallyChecksForUpdates = YES; });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{ [driver.updater checkForUpdates]; });
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [driver finish:@"timeout"]; });
        [app run];
    }
}
