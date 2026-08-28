#import <UIKit/UIKit.h>

@interface CCUILowPowerModuleViewController : UIViewController
- (void)updateBatteryLabel;
@end

%hook CCUILowPowerModuleViewController

- (void)viewDidLoad {
    %orig;
    
    // 監聽電量變化
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateBatteryLabel)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateBatteryLabel)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self updateBatteryLabel];
}

%new
- (void)updateBatteryLabel {
    UIView *parentView = self.view;
    if (!parentView) return;

    // 獲取當前電量
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    // 尋找或創建 Label
    UILabel *label = (UILabel *)[parentView viewWithTag:9999];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 9999;
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        
        [parentView addSubview:label];

        // 將 Label 強制固定在按鈕視圖的正中央偏下方
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor],
            [label.centerYAnchor constraintEqualToAnchor:parentView.centerYAnchor constant:12]
        ]];
    }

    // 設定顯示文字
    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"%";
    }

    // 低電量模式開啟時文字變黑色，否則為白色
    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    // 強制置頂，防止被圖示遮擋
    [parentView bringSubviewToFront:label];
}

%end
