#import <UIKit/UIKit.h>

@interface CCUIRoundButton : UIView
@property (nonatomic, strong) UIImageView *glyphImageView;
@end

@interface CCUIRoundButtonViewController : UIViewController
@property (nonatomic, strong) CCUIRoundButton *buttonView;
- (void)updateCowbellText;
@end

@interface CCUILowPowerModuleViewController : CCUIRoundButtonViewController
@end


%hook CCUILowPowerModuleViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self updateCowbellText];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self updateCowbellText];
}

%new
- (void)updateCowbellText {
    // 取得模組主要 View
    UIView *mainContainer = self.view;
    if (!mainContainer) return;

    // 取得目前電量
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    // 尋找或創建 Label
    UILabel *label = (UILabel *)[mainContainer viewWithTag:77777];
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.tag = 77777;
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        
        // 為了測試 Hook 是否真的加載成功，加一個紅色背景（生效後可删掉）
        label.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5];
        
        [mainContainer addSubview:label];

        // 綁定 AutoLayout 邊界，強制跟隨父視圖大小
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:mainContainer.centerXAnchor],
            [label.centerYAnchor constraintEqualToAnchor:mainContainer.centerYAnchor constant:10],
            [label.widthAnchor constraintEqualToAnchor:mainContainer.widthAnchor],
            [label.heightAnchor constraintEqualToConstant:16]
        ]];
    }

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"99%"; // 測試預設值
    }

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    // 關鍵操作：強制置於最高層
    [mainContainer bringSubviewToFront:label];
}

%end
