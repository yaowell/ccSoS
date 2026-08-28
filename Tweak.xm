#import <UIKit/UIKit.h>

@interface CCUILowPowerModuleViewController : UIViewController
- (void)updateCowbellPercent;
@end

%hook CCUILowPowerModuleViewController

- (void)viewDidLoad {
    %orig;
    
    // 監聽系統電量廣播
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellPercent)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellPercent)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self updateCowbellPercent];
}

%new
- (void)updateCowbellPercent {
    UIView *mainView = self.view;
    if (!mainView) return;

    // 取得當前 View 的寬高
    CGFloat width = mainView.bounds.size.width;
    CGFloat height = mainView.bounds.size.height;
    if (width <= 0 || height <= 0) return;

    // 取得精確電量
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    // 尋找或創建標籤 (Tag: 6666)
    UILabel *label = (UILabel *)[mainView viewWithTag:6666];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 6666;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        [mainView addSubview:label];
    }

    // 使用絕對座標 Frame，直接貼在圖示下方偏中心位置（避免 AutoLayout 失敗）
    label.frame = CGRectMake(0, height - 18, width, 14);

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"--%";
    }

    // 顏色切換
    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    // 關鍵：永遠提至最頂層，防止被電池圖案遮擋
    [mainView bringSubviewToFront:label];
}

%end
