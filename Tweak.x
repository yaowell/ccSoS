#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUILowPowerModeModuleViewController : UIViewController
@property (nonatomic, assign) BOOL cb_observerRegistered;
- (void)cb_updateLabelText;
- (void)cb_findAndSetLabelText:(UIView *)parent text:(NSString *)text;
@end

@interface CCUILowPowerModeModule : NSObject
@end

%hook CCUILowPowerModeModule

- (UIViewController *)contentViewController {
    UIViewController *vc = %orig;
    Class targetClass = NSClassFromString(@"CCUILowPowerModeModuleViewController");
    
    if (vc && targetClass && [vc isKindOfClass:targetClass]) {
        CCUILowPowerModeModuleViewController *lpVc = (CCUILowPowerModeModuleViewController *)vc;
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        
        if (!lpVc.cb_observerRegistered) {
            lpVc.cb_observerRegistered = YES;
            [[NSNotificationCenter defaultCenter] addObserver:lpVc
                                                     selector:@selector(cb_updateLabelText)
                                                         name:UIDeviceBatteryLevelDidChangeNotification
                                                       object:nil];
        }
    }
    return vc;
}

%end

%hook CCUILowPowerModeModuleViewController
%property (nonatomic, assign) BOOL cb_observerRegistered;

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self cb_updateLabelText];
}

- (void)viewDidLayoutSubviews {
    %orig;
    // 確保視圖完成首組 Layout 後再刷一次，防止 viewWillAppear 時子視圖尚未 Attach
    [self cb_updateLabelText];
}

%new
- (void)cb_updateLabelText {
    // 切換回主線程執行 UI 更新
    dispatch_async(dispatch_get_main_queue(), ^{
        float level = [UIDevice currentDevice].batteryLevel;
        int percent = (level >= 0) ? (int)round(level * 100.0f) : 100;
        NSString *percentStr = [NSString stringWithFormat:@"%d%%", percent];
        
        if (self.view) {
            [self cb_findAndSetLabelText:self.view text:percentStr];
        }
        NSLog(@"[SimpleCowbell] cb_updateLabelText trigger: %@", percentStr);
    });
}

%new
- (void)cb_findAndSetLabelText:(UIView *)parent text:(NSString *)text {
    if (!parent) return;
    
    for (UIView *subview in parent.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSLog(@"[SimpleCowbell] Found label, oldText: %@", label.text);
            if (![label.text isEqualToString:text]) {
                label.text = text;
            }
        } else if (subview.subviews.count > 0) {
            [self cb_findAndSetLabelText:subview text:text];
        }
    }
}

- (void)dealloc {
    if (self.cb_observerRegistered) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    %orig; // 遵循规范：先清理自身 Observer/状态，再调用父类/原生的 %orig 销毁
}

%end

%ctor {
    NSLog(@"[SimpleCowbell] LowPowerModule precision hook loaded successfully.");
}
