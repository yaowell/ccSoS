#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUILowPowerModeModuleViewController : UIViewController
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updatePercentText;
@end

%hook CCUILowPowerModeModuleViewController

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)viewDidLoad {
    %orig;
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
}

- (void)viewDidLayoutSubviews {
    %orig;
    
    // 强制允许子视图超出边界展示
    self.view.clipsToBounds = NO;
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    if (width <= 0 || height <= 0) return;

    // 1. 遍历并向上强制平移原生电池图标（无论是 ImageView 还是 CCUICAPackageView）
    for (UIView *subview in self.view.subviews) {
        if (subview != self.cbPercentLabel) {
            // 强行关闭自动布局限制，手动设定 Frame
            subview.translatesAutoresizingMaskIntoConstraints = YES;
            
            // 将中心点向上移动 6 个点
            CGPoint center = subview.center;
            center.y = (height / 2) - 6;
            subview.center = center;
        }
    }

    // 2. 创建底部的百分比 Label
    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] init];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        lab.textColor = [UIColor whiteColor];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        self.cbPercentLabel = lab;
        [self.view addSubview:lab];

        // 注册电量变化通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cb_updatePercentText)
                                                     name:UIDeviceBatteryLevelDidChangeNotification
                                                   object:nil];
    }

    // 3. 将百分比 Label 放置在模块最底部
    self.cbPercentLabel.frame = CGRectMake(0, height - 15, width, 12);
    [self.view bringSubviewToFront:self.cbPercentLabel];
    
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
    NSLog(@"[SimpleCowbell] Target CCUILowPowerModeModuleViewController directly.");
}
