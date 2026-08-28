#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIBatteryStatusItemView : UIView
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updateText;
@end

%hook CCUIBatteryStatusItemView

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)didMoveToSuperview {
    %orig;
    
    // 必須開啟系統電量監測，否則 batteryLevel 為 -1
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] init];
        lab.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        lab.textColor = [UIColor whiteColor];
        lab.frame = CGRectMake(-24, 1, 22, 13);
        lab.textAlignment = NSTextAlignmentRight;
        
        self.cbPercentLabel = lab;
        [self addSubview:lab];

        // 監聽電量變化通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cb_updateText)
                                                     name:UIDeviceBatteryLevelDidChangeNotification
                                                   object:nil];
    }
    
    [self cb_updateText];
}

- (void)layoutSubviews {
    %orig;
    // 移除 [self cb_updateText] 避免 layoutSubviews 陷入死迴圈崩潰！
    // 僅在 Frame 改變時調整 Label 位置（如有需要）
    if (self.cbPercentLabel) {
        [self bringSubviewToFront:self.cbPercentLabel];
    }
}

%new
- (void)cb_updateText {
    float level = [UIDevice currentDevice].batteryLevel;
    
    // 處理無效電量情況
    if (level < 0) {
        self.cbPercentLabel.text = @"100%";
    } else {
        int percent = (int)(level * 100);
        self.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%", percent];
    }
}

%end

%ctor {
    NSLog(@"[SimpleCowbell] Loaded successfully into CCUIBatteryStatusItemView!");
}
