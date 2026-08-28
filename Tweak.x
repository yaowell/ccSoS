#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUILowPowerModeModuleViewController : UIViewController
@property (nonatomic, strong) UILabel *cbPercentLabel;
@property (nonatomic, assign) BOOL cb_observerRegistered;
- (void)cb_updatePercentText;
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
                                                     selector:@selector(cb_updatePercentText)
                                                         name:UIDeviceBatteryLevelDidChangeNotification
                                                       object:nil];
        }
    }
    return vc;
}

%end

%hook CCUILowPowerModeModuleViewController
%property (nonatomic, strong) UILabel *cbPercentLabel;
%property (nonatomic, assign) BOOL cb_observerRegistered;

- (void)viewDidLayoutSubviews {
    %orig;
    
    self.view.clipsToBounds = NO;
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    if (width <= 0 || height <= 0) return;

    // 1. 將原生電池 Glyph/ImageView 向上微移，給底部留出文字空間
    for (UIView *subview in self.view.subviews) {
        if (subview != self.cbPercentLabel) {
            // 向上平移 6 個點，縮小一點點高度
            subview.frame = CGRectMake(0, -6, width, height - 8);
        }
    }

    // 2. 初始化底部百分比 Label
    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] init];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        lab.textColor = [UIColor whiteColor];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        self.cbPercentLabel = lab;
        [self.view addSubview:lab];
    }

    // 3. 將 Label 擺放在模組底端 (高度 14pt)
    self.cbPercentLabel.frame = CGRectMake(0, height - 16, width, 14);
    [self.view bringSubviewToFront:self.cbPercentLabel];
    
    [self cb_updatePercentText];
}

%new
- (void)cb_updatePercentText {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.cbPercentLabel) return;
        
        float level = [UIDevice currentDevice].batteryLevel;
        int percent = (level >= 0) ? (int)round(level * 100.0f) : 100;
        
        strongSelf.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%", percent];
    });
}

- (void)dealloc {
    if (self.cb_observerRegistered) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    %orig;
}

%end

%ctor {
    NSLog(@"[SimpleCowbell] LowPowerMode vertical layout loaded.");
}
