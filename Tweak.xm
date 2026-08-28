#import <UIKit/UIKit.h>

@interface CCUILowPowerModuleViewController : UIViewController
- (void)updateCowbellLabel;
@end

// 將 Hook 放入 Group 中，防止開機時因 Class 未載入而失效
%group LowPowerGroup

%hook CCUILowPowerModuleViewController

- (void)viewDidLoad {
    %orig;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellLabel)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellLabel)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self updateCowbellLabel];
}

%new
- (void)updateCowbellLabel {
    UIView *targetContainer = self.view;
    if (!targetContainer) return;

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    UILabel *label = (UILabel *)[targetContainer viewWithTag:88888];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 88888;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [targetContainer addSubview:label];

        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:targetContainer.centerXAnchor],
            [label.centerYAnchor constraintEqualToAnchor:targetContainer.centerYAnchor constant:12]
        ]];
    }

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"%";
    }

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    [targetContainer bringSubviewToFront:label];
}

%end

%end // end LowPowerGroup


// 插件入口（Constructor）：監聽 Bundle 載入時機
%ctor {
    @autoreleasepool {
        // 定義 Hook 初始化邏輯
        void (^initHook)(void) = ^{
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                %init(LowPowerGroup);
            });
        };

        // 情況 A：如果 LowPowerModule 已經在記憶體中，直接 Hook
        NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.apple.controlcenter.LowPowerModule"];
        if (bundle && bundle.isLoaded) {
            initHook();
        } else {
            // 情況 B：如果還沒載入，監聽 Bundle 載入通知，載入完成瞬間立刻 Hook
            [[NSNotificationCenter defaultCenter] addObserverForName:NSBundleDidLoadNotification
                                                              object:nil
                                                               queue:nil
                                                          usingBlock:^(NSNotification *note) {
                NSBundle *loadedBundle = [note object];
                if ([loadedBundle.bundleIdentifier isEqualToString:@"com.apple.controlcenter.LowPowerModule"]) {
                    initHook();
                }
            }];
        }
    }
}
