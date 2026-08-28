#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUILowPowerModeModule : NSObject
@end

@interface CCUIContentModuleContentViewController : UIViewController
- (void)cb_updateLabelText;
@end

// Hook 低電量模組對應的 View Controller 或 View
%hook CCUILowPowerModeModule

- (UIViewController *)contentViewController {
    UIViewController *vc = %orig;
    if (vc) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        // 監聽電量變化
        [[NSNotificationCenter defaultCenter] addObserver:vc
                                                 selector:@selector(cb_updateLabelText)
                                                     name:UIDeviceBatteryLevelDidChangeNotification
                                                   object:nil];
    }
    return vc;
}

%end

// 針對控制中心模組視圖進行文字替換
%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    NSString *clsName = NSStringFromClass([self class]);
    if ([clsName containsString:@"LowPower"] || [clsName containsString:@"CCUI"]) {
        [self cb_updateLabelText];
    }
}

%new
- (void)cb_updateLabelText {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0f) : 100;
    NSString *percentStr = [NSString stringWithFormat:@"%d%%", percent];

    // 遞歸尋找視圖內的 UILabel 並替換文字
    [self cb_findAndSetLabelText:self.view text:percentStr];
}

%new
- (void)cb_findAndSetLabelText:(UIView *)parent text:(NSString *)text {
    for (UIView *subview in parent.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            // 防死迴圈：只有當文字不一致時才賦值
            if (![label.text isEqualToString:text]) {
                label.text = text;
            }
        } else if (subview.subviews.count > 0) {
            [self cb_findAndSetLabelText:subview text:text];
        }
    }
}

%end

%ctor {
    NSLog(@"[SimpleCowbell] Hook CCUILowPowerModeModule loaded successfully!");
}
