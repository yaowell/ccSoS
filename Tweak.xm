#import <UIKit/UIKit.h>

@interface CCUIRoundButtonViewController : UIViewController
@property (nonatomic, copy) NSString *glyphState;
- (void)updateCowbellLabel;
@end

%hook CCUIRoundButtonViewController

- (void)viewDidLoad {
    %orig;
    
    // 监听电量改变广播
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
    // 只有当前 VC 是控制中心低电量模块时才执行
    NSString *className = NSStringFromClass([self class]);
    if (![className containsString:@"LowPower"] && ![className containsString:@"Battery"]) {
        // 如果类名不含 LowPower，再检查父级类名
        NSString *parentClass = NSStringFromClass([[self parentViewController] class]);
        if (![parentClass containsString:@"LowPower"]) {
            return;
        }
    }

    UIView *targetView = self.view;
    if (!targetView) return;

    // 获取系统原生电量
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float batteryLevel = [UIDevice currentDevice].batteryLevel;
    int percent = (batteryLevel >= 0) ? (int)round(batteryLevel * 100.0) : 0;

    UILabel *label = (UILabel *)[targetView viewWithTag:88888];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 88888;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [targetView addSubview:label];

        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:targetView.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:targetView.bottomAnchor constant:-4]
        ]];
    }

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"%";
    }

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    [targetView bringSubviewToFront:label];
}

%end
