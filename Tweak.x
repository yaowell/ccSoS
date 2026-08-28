#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 1. 明确声明 CCUIContentModuleContentView 继承自 UIView
@interface CCUIContentModuleContentView : UIView
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updateText;
@end

@interface CCUILowPowerModeModuleViewController : UIViewController
@end

// 2. 挂载动态属性到 UIView 容器
%hook UIView
%property (nonatomic, strong) UILabel *cbPercentLabel;
%end

// 3. 监听低电量 Controller
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

// 4. Hook 模块 ContentView 进行 UI 上图下文排版
%hook CCUIContentModuleContentView

- (void)layoutSubviews {
    %orig;
    
    // 判断 Responder 链，仅拦截低电量模块
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

    // A. 向上平移图标视图
    for (UIView *subview in self.subviews) {
        if (subview != self.cbPercentLabel) {
            subview.translatesAutoresizingMaskIntoConstraints = YES;
            CGRect frame = subview.frame;
            frame.origin.y = (height - frame.size.height) / 2 - 7;
            subview.frame = frame;
        }
    }

    // B. 创建底部百分比 Label
    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] init];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        lab.textColor = [UIColor whiteColor];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        self.cbPercentLabel = lab;
        [self addSubview:lab];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cb_updateText)
                                                     name:UIDeviceBatteryLevelDidChangeNotification
                                                   object:nil];
    }

    // C. 放置 Label 在最底端
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
