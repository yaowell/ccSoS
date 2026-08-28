#import <UIKit/UIKit.h>

@interface CCUILowPowerModuleViewController : UIViewController
- (void)cc_updateBatteryLabel;
@end

@interface CCUIRoundButtonViewController : UIViewController
- (void)cc_updateBatteryLabel;
@end

// 宣告 Hook Group
%group CCBatteryGroup

%hook CCUILowPowerModuleViewController

- (void)viewDidLayoutSubviews {
    %orig;
    [self cc_updateBatteryLabel];
}

%new
- (void)cc_updateBatteryLabel {
    UIView *container = self.view;
    if (!container || container.bounds.size.width <= 0) return;

    // 開啟電量監測
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    UILabel *label = (UILabel *)[container viewWithTag:88888];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 88888;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        [container addSubview:label];
    }

    // 設定絕對佈局（底部 8pt 位置）
    CGFloat width = container.bounds.size.width;
    CGFloat height = container.bounds.size.height;
    label.frame = CGRectMake(0, height - 18, width, 14);

    label.text = (percent > 0) ? [NSString stringWithFormat:@"%d%%", percent] : @"--%";

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    [container bringSubviewToFront:label];
}

%end

%end // end group

// 解決動態加載 Bundle 的致命死穴
%ctor {
    @autoreleasepool {
        void (^initTweak)(void) = ^{
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                %init(CCBatteryGroup);
            });
        };

        // 檢查 LowPowerModule 是否已載入
        NSBundle *lpmBundle = [NSBundle bundleWithIdentifier:@"com.apple.controlcenter.LowPowerModule"];
        if (lpmBundle && lpmBundle.isLoaded) {
            initTweak();
        } else {
            // 未載入時，監聽 Bundle 載入廣播
            [[NSNotificationCenter defaultCenter] addObserverForName:NSBundleDidLoadNotification
                                                              object:nil
                                                               queue:nil
                                                          usingBlock:^(NSNotification *note) {
                NSBundle *bundle = [note object];
                if ([bundle.bundleIdentifier isEqualToString:@"com.apple.controlcenter.LowPowerModule"]) {
                    initTweak();
                }
            }];
        }
    }
}
