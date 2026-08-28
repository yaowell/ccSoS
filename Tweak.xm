#import <UIKit/UIKit.h>

// 聲明低電量模組控制器
@interface CCUILowPowerModuleViewController : UIViewController
- (void)refreshBatteryLabel;
@end

%hook CCUILowPowerModuleViewController

// 1. 當模組載入時，註冊電量變化通知
- (void)viewDidLoad {
    %orig;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshBatteryLabel)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshBatteryLabel)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
}

// 2. 每次視圖佈局（控制中心打開或旋轉時）觸發文字更新
- (void)viewWillLayoutSubviews {
    %orig;
    [self refreshBatteryLabel];
}

// 3. 自定義繪製與刷新邏輯
%new
- (void)refreshBatteryLabel {
    UIView *mainView = self.view;
    if (!mainView) return;

    // 開啟系統電量監測並獲取百分比
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    // 使用 Tag 避免重複創建 Label
    UILabel *label = (UILabel *)[mainView viewWithTag:7777];
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.tag = 7777;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [mainView addSubview:label];

        // 自動佈局：橫向居中，距離底部 6 像素
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:mainView.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:mainView.bottomAnchor constant:-6]
        ]];
    }

    // 更新顯示文字
    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"--%";
    }

    // 根據是否開啟低電量模式切換顏色（開啟時圖示變黃，文字設為黑色更清晰）
    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    // 確保文字處於最上層
    [mainView bringSubviewToFront:label];
}

%end
