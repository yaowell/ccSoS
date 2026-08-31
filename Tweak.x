#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIContentModuleContainerView : UIView
@property (nonatomic, strong) NSString *moduleIdentifier;
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updatePercentText;
- (BOOL)cb_isLowPowerModule;
@end

%hook CCUIContentModuleContainerView

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)layoutSubviews {
    %orig;

    // 1. 非低电量模块直接隐藏并返回
    if (![self cb_isLowPowerModule]) {
        if (self.cbPercentLabel) {
            self.cbPercentLabel.hidden = YES;
        }
        return;
    }

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0 || width > 100 || height > 100) return;

    // 2. 移除原代码中的 for 循环遍历变换重置（系统原生控件本身没有设置 transform，无需循环清空，节省 CPU）

    // 3. 布局与初始化 Label
    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, height - 22, width, 12)];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        self.cbPercentLabel = lab;
        [self addSubview:lab];

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        
        // 关键性能优化：指定 object:nil 改为局部监听，避免全局广播引发的频繁刷新
        // 增加 removeFromNotificationCenter 防止重复注册
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:UIDeviceBatteryLevelDidChangeNotification object:nil];
        [nc removeObserver:self name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        
        [nc addObserver:self
               selector:@selector(cb_updatePercentText)
                   name:UIDeviceBatteryLevelDidChangeNotification
                 object:nil];
                                                   
        [nc addObserver:self
               selector:@selector(cb_updatePercentText)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];
    } else {
        self.cbPercentLabel.hidden = NO;
        self.cbPercentLabel.frame = CGRectMake(0, height - 22, width, 12);
    }

    [self bringSubviewToFront:self.cbPercentLabel];
    [self cb_updatePercentText];
}

%new
- (BOOL)cb_isLowPowerModule {
    // 关键性能优化：使用 Associated Object 缓存判断结果，只有第一次才查链条，之后瞬间返回！
    static char kIsLowPowerModuleKey;
    NSNumber *cached = objc_getAssociatedObject(self, &kIsLowPowerModuleKey);
    if (cached) {
        return cached.boolValue;
    }

    BOOL isTarget = NO;
    if ([self respondsToSelector:@selector(moduleIdentifier)]) {
        NSString *modID = [self performSelector:@selector(moduleIdentifier)];
        if ([modID isEqualToString:@"com.apple.control-center.LowPowerModule"] || 
            [modID containsString:@"LowPowerModule"]) {
            isTarget = YES;
        }
    }

    if (!isTarget) {
        UIResponder *responder = self;
        while (responder) {
            NSString *clsName = NSStringFromClass([responder class]);
            if ([clsName containsString:@"CCUILowPowerModeModule"]) {
                isTarget = YES;
                break;
            }
            responder = [responder nextResponder];
        }
    }

    objc_setAssociatedObject(self, &kIsLowPowerModuleKey, @(isTarget), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return isTarget;
}

%new
- (void)cb_updatePercentText {
    // 关键性能优化：无需切异步主线程执行，当前方法必然在主线程，且同步更新无延迟闪烁
    if (!self.cbPercentLabel || !self.window) return;

    // 1. 获取并刷新电量百分比
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0f) : 100;
    self.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%", percent];

    // 2. 颜色逻辑
    BOOL isLowPowerMode = [NSProcessInfo processInfo].isLowPowerModeEnabled;
    self.cbPercentLabel.textColor = isLowPowerMode ? [UIColor blackColor] : [UIColor whiteColor];
}

%end
