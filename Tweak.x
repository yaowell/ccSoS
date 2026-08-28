#import <UIKit/UIKit.h>

// 聲明 iOS 16 私有類 CCUIBatteryView
@interface CCUIBatteryView : UIView
@property (nonatomic, strong) UILabel *cb_percentLabel;
@end

%hook CCUIBatteryView

// 使用 Associated Object (關聯對象) 安全儲存 Property，防止多實例衝突
%property (nonatomic, strong) UILabel *cb_percentLabel;

- (instancetype)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        [self cb_setupBatteryMonitoring];
    }
    return self;
}

- (void)layoutSubviews {
    %orig;

    // 確保開啟電量監測
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    // 獲取或創建 Label
    UILabel *label = self.cb_percentLabel;
    if (!label) {
        label = [[UILabel alloc] init];
        label.font = [UIFont boldSystemFontOfSize:9.0];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = [UIColor clearColor];
        label.userInteractionEnabled = NO;
        
        self.cb_percentLabel = label;
        [self addSubview:label];
    }

    // 計算電量
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0f) : 0;

    if (level >= 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"";
    }

    // 動態根據低電量模式切換字體顏色（開啟低電量模式時電池背景變黃，字體切換為黑色）
    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    // 居中佈局，精確計算邊距防止溢出
    CGFloat insetX = 2.0f;
    CGFloat insetY = 1.0f;
    label.frame = CGRectMake(insetX, insetY,
                             CGRectGetWidth(self.bounds) - insetX * 2,
                             CGRectGetHeight(self.bounds) - insetY * 2);

    // 強制提至最頂層
    [self bringSubviewToFront:label];
}

%new
- (void)cb_setupBatteryMonitoring {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    
    // 監聽電量變化與低電量模式開關，隨時觸發重新繪製
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setNeedsLayout)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setNeedsLayout)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
}

%end
