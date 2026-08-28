#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUILowPowerModeModuleViewController : UIViewController
@end

// 声明全局电量百分比 Label 动态属性
@interface UIView (Cowbell)
@property (nonatomic, strong) UILabel *cbPercentLabel;
@end

%hook UIView

%property (nonatomic, strong) UILabel *cbPercentLabel;

%end

// 1. Hook 低电量模块的 Controller，确保开启电量监听
%hook CCUILowPowerModeModuleViewController

- (void)viewDidLoad {
    %orig;
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self.view setNeedsLayout];
}

%end

// 2. 直接 Hook 控制中心模块 Content View 的 layoutSubviews
%hook CCUIContentModuleContentView

- (void)layoutSubviews {
    %orig;
    
    // 确认当前 View 是否属于低电量模块
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    
    if (!responder || ![NSStringFromClass([responder class]) containsString:@"LowPower"]) {
        return;
    }

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0) return;

    // A. 将原生的 Icon/Glyph 视图整体向上平移，并关闭 translatesAutoresizingMaskIntoConstraints
    for (UIView *subview in self.subviews) {
        if (subview != self.cbPercentLabel) {
            subview.translatesAutoresizingMaskIntoConstraints = YES; // 允许手动改 Frame
            CGRect frame = subview.frame;
            frame.origin.y = (height - frame.size.height) / 2 - 7; // 向上偏移 7pt
            subview.frame = frame;
        }
    }

    // B. 初始化底部百分比 Label
    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] init];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        lab.textColor = [UIColor whiteColor];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        self.cbPercentLabel = lab;
        [self addSubview:lab];

        // 注册电量变化通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cb_updateText)
                                                     name:UIDeviceBatteryLevelDidChangeNotification
                                                   object:nil];
    }

    // C. 放置 Label 在最底部
    self.cbPercentLabel.frame = CGRectMake(0, height - 16, width, 12);
    [self bringSubviewToFront:self.cbPercentLabel];
    
    [self cb_updateText];
}

%new
- (void)cb_updateText {
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0f) : 100;
    if (self.cbPercentLabel) {
        self.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%", percent];
    }
}

%end

%ctor {
    NSLog(@"[SimpleCowbell] LowPowerMode Layout Overrider loaded.");
}
