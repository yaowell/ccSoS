#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明 iOS 控制中心低电量模块核心类及其属性
@interface CCUILowPowerModeModule : UIViewController
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updatePercentText;
@end

%hook CCUILowPowerModeModule

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)viewDidLoad {
    %orig;
    
    // 开启设备电池状态监听
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cb_updatePercentText)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    %orig;

    // 防止子视图超越边界时被剪切
    self.view.clipsToBounds = NO;
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    if (width <= 0 || height <= 0) return;

    // 1. 使用 transform 强行将电池图标向上平移 6pt（绕过 Auto Layout 重置）
    for (UIView *subview in self.view.subviews) {
        if (subview != self.cbPercentLabel) {
            subview.transform = CGAffineTransformMakeTranslation(0, -6);
        }
    }

    // 2. 初始化或更新底部百分比 Label
    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, height - 15, width, 12)];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        lab.textColor = [UIColor whiteColor];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        // 添加阴影提升高亮显示时的可读性
        lab.layer.shadowColor = [UIColor blackColor].CGColor;
        lab.layer.shadowOffset = CGSizeMake(0, 0);
        lab.layer.shadowOpacity = 0.5;
        lab.layer.shadowRadius = 1.0;

        self.cbPercentLabel = lab;
        [self.view addSubview:lab];
    } else {
        self.cbPercentLabel.frame = CGRectMake(0, height - 15, width, 12);
    }

    // 保证百分比 Label 在最顶层
    [self.view bringSubviewToFront:self.cbPercentLabel];
    
    // 触发电量更新刷新
    [self cb_updatePercentText];
}

%new
- (void)cb_updatePercentText {
    dispatch_async(dispatch_get_main_queue(), ^{
        float level = [UIDevice currentDevice].batteryLevel;
        int percent = (level >= 0) ? (int)round(level * 100.0f) : 100;
        if (self.cbPercentLabel) {
            self.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%", percent];
        }
    });
}

%end

%ctor {
    NSLog(@"[SimpleCowbell] Successfully injected into Control Center.");
}
