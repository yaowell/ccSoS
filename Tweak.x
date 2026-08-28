#import <UIKit/UIKit.h>

@interface CCUIBatteryView : UIView
@property (nonatomic, retain) UILabel *cb_percentLabel;
- (void)cb_setupBatteryMonitoring;
- (void)cb_updateBatteryLevel;
@end

%hook CCUIBatteryView

// 1. Hook 通用初始化方法
- (instancetype)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        [self cb_setupBatteryMonitoring];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = %orig;
    if (self) {
        [self cb_setupBatteryMonitoring];
    }
    return self;
}

// 2. 當視圖添加到父視圖時更新電量
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        [self cb_updateBatteryLevel];
    }
}

%new
- (void)cb_setupBatteryMonitoring {
    // 開啟系統電量監測
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    // 如果 Label 還沒建立，就建立一個新的 UILabel 覆蓋在圖示上
    if (!self.cb_percentLabel) {
        UILabel *label = [[UILabel alloc] initWithFrame:self.bounds];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
        label.textColor = [UIColor whiteColor];
        
        [self addSubview:label];
        self.cb_percentLabel = label;
    }

    // 監聽電量變化通知
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(cb_updateBatteryLevel) 
                                                 name:UIDeviceBatteryLevelDidChangeNotification 
                                               object:nil];
    
    [self cb_updateBatteryLevel];
}

%new
- (void)cb_updateBatteryLevel {
    float level = [UIDevice currentDevice].batteryLevel;
    if (level < 0) {
        self.cb_percentLabel.text = @"--%";
    } else {
        self.cb_percentLabel.text = [NSString stringWithFormat:@"%.0f%%", level * 100];
    }
}

// 綁定自訂屬性 (Associated Object)
%property (nonatomic, retain) UILabel *cb_percentLabel;

%end

%ctor {
    NSLog(@"[SimpleCowbell] Loaded successfully into Control Center!");
}
