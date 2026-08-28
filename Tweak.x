#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIRoundButtonViewController : UIViewController
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updatePercentText;
@end

%hook CCUIRoundButtonViewController

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)viewDidLoad {
    %orig;
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
}

- (void)viewDidLayoutSubviews {
    %orig;

    // 获取当前按钮视图对应的模块标识/类名
    NSString *parentClass = NSStringFromClass([self.parentViewController class]);
    NSString *selfClass = NSStringFromClass([self class]);
    
    // 如果不是低电量相关控件，则跳过（注：如果还是没效果，把下面这个 if 整体注释掉，就能强行让控制中心所有按钮都显示电量，以此排除注入问题）
    BOOL isBatteryModule = [parentClass containsString:@"LowPower"] || [parentClass containsString:@"Battery"] || [selfClass containsString:@"LowPower"];
    if (!isBatteryModule) {
        return;
    }

    self.view.clipsToBounds = NO;
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    if (width <= 0 || height <= 0) return;

    // 1. 强制平移内部图标
    for (UIView *subview in self.view.subviews) {
        if (subview != self.cbPercentLabel) {
            subview.transform = CGAffineTransformMakeTranslation(0, -6);
        }
    }

    // 2. 注入或更新 Label
    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, height - 15, width, 12)];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        lab.textColor = [UIColor whiteColor];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        self.cbPercentLabel = lab;
        [self.view addSubview:lab];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cb_updatePercentText)
                                                     name:UIDeviceBatteryLevelDidChangeNotification
                                                   object:nil];
    } else {
        self.cbPercentLabel.frame = CGRectMake(0, height - 15, width, 12);
    }

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
    NSLog(@"[Cowbell] Universal RoundButton Hook Loaded!");
}
