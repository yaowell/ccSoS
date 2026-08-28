#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIBatteryModule : UIView
- (void)cb_updateBatteryText;
- (void)cb_walkAndSetPercent:(UIView *)root text:(NSString *)text;
@end

%hook CCUIBatteryModule

- (void)didMoveToSuperview {
    %orig;
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    
    // 監聽電量變化
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cb_updateBatteryText)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [self cb_updateBatteryText];
}

- (void)layoutSubviews {
    %orig;
    [self cb_updateBatteryText];
}

%new
- (void)cb_updateBatteryText {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    
    int p = (level >= 0) ? (int)round(level * 100.0f) : 100;
    NSString *newText = [NSString stringWithFormat:@"%d%%", p];
    
    [self cb_walkAndSetPercent:self text:newText];
}

%new
- (void)cb_walkAndSetPercent:(UIView *)root text:(NSString *)text {
    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:[UILabel class]]) {
            UILabel *lab = (UILabel *)v;
            // 核心防死迴圈：只有當文字真的改變時才賦值，防止觸發 layoutSubviews 死迴圈
            if (![lab.text isEqualToString:text]) {
                lab.text = text;
            }
        } else if (v.subviews.count > 0) {
            [self cb_walkAndSetPercent:v text:text];
        }
    }
}

%end

%ctor {
    NSLog(@"[SimpleCowbell] Hook CCUIBatteryModule loaded");
}
