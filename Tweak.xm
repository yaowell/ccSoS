#import <UIKit/UIKit.h>

@interface CCUIRoundButtonViewController : UIViewController
- (void)updateCowbellPercent;
@end

%hook CCUIRoundButtonViewController

- (void)viewDidLayoutSubviews {
    %orig;
    [self updateCowbellPercent];
}

%new
- (void)updateCowbellPercent {
    // 檢查目前 VC 的類名或父層類名，確認是不是低電量模組
    NSString *className = NSStringFromClass([self class]);
    NSString *parentName = self.parentViewController ? NSStringFromClass([self.parentViewController class]) : @"";
    
    BOOL isLowPower = [className containsString:@"LowPower"] || [parentName containsString:@"LowPower"];
    
    // 如果不是低電量模組，直接退出，不影響手電筒、鬧鐘等其他按鈕
    if (!isLowPower) return;

    UIView *mainView = self.view;
    if (!mainView) return;

    CGFloat width = mainView.bounds.size.width;
    CGFloat height = mainView.bounds.size.height;
    if (width <= 0 || height <= 0) return;

    // 取得電量
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    UILabel *label = (UILabel *)[mainView viewWithTag:6666];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 6666;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        [mainView addSubview:label];
    }

    label.frame = CGRectMake(0, height - 16, width, 14);

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"--%";
    }

    BOOL isLPMEnabled = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLPMEnabled ? [UIColor blackColor] : [UIColor whiteColor];

    [mainView bringSubviewToFront:label];
}

%end
