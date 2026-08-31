#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

// iOS 16 控制中心模块容器类
@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@property (nonatomic, retain) UILabel *cowbellLabel;
@end

// 驱动系统原生 PackageView 的 CoreAnimation 时间轴，实现 Live Battery Indicator
static void updateLiveBatteryPackage(UIView *view, float batteryLevel) {
    if (!view) return;

    if ([NSStringFromClass([view class]) containsString:@"CCUICAPackageView"]) {
        CALayer *packageLayer = view.layer;

        // 递归遍历 PackageView 图层中的所有 KeyframeAnimation 和 Sublayer
        // 冻结动画 speed = 0，将 timeOffset 锁定在 batteryLevel (0.0 ~ 1.0) 对应的百分比位置
        NSMutableArray *layers = [NSMutableArray arrayWithObject:packageLayer];
        while (layers.count > 0) {
            CALayer *l = [layers firstObject];
            [nodesOrLayers removeObjectAtIndex:0]; // 清理队列

            l.speed = 0.0;
            l.timeOffset = (CFTimeInterval)batteryLevel;

            if (l.sublayers) {
                [layers addObjectsFromArray:l.sublayers];
            }
        }
        return;
    }

    for (UIView *subview in view.subviews) {
        updateLiveBatteryPackage(subview, batteryLevel);
    }
}

%hook CCUIContentModuleContainerViewController
%property (nonatomic, retain) UILabel *cowbellLabel;

- (void)viewDidLoad {
    %orig;

    // 1. 精准锁定低电量控制模块
    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        // 2. 初始化原版 Cowbell 百分比 Label
        if (!self.cowbellLabel) {
            UILabel *label = [[UILabel alloc] init];
            label.textColor = [UIColor whiteColor];
            label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
            label.textAlignment = NSTextAlignmentCenter;
            
            label.layer.allowsGroupBlending = NO;
            label.layer.allowsGroupOpacity = YES;

            [self.view addSubview:label];
            self.cowbellLabel = label;
        }
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"] && self.cowbellLabel) {
        
        // 3. 动态获取实时电量
        float level = [[UIDevice currentDevice] batteryLevel];
        float safeLevel = (level < 0) ? 1.0 : level;
        int battery = (int)round(safeLevel * 100);

        // 刷新百分比数字
        self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.cowbellLabel sizeToFit];

        // 置顶防止遮挡
        [self.view bringSubviewToFront:self.cowbellLabel];

        // 计算布局坐标（居中挂在 70% 高度处）
        CGFloat viewW = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : 72.0;
        CGFloat viewH = self.view.bounds.size.height > 0 ? self.view.bounds.size.height : 72.0;
        CGFloat labelW = self.cowbellLabel.frame.size.width;
        CGFloat labelH = self.cowbellLabel.frame.size.height;

        self.cowbellLabel.frame = CGRectMake(
            (viewW - labelW) / 2.0,
            viewH * 0.70 - (labelH / 2.0),
            labelW,
            labelH
        );

        // 4. 处理低电量模式开启时的“镂空反色”
        BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
        if (isLPMOn) {
            self.cowbellLabel.layer.compositingFilter = kCAFilterDestOut;
        } else {
            self.cowbellLabel.layer.compositingFilter = nil;
        }

        // 5. 复刻 Live Battery Indicator：驱动系统原生电池图标的填充柱
        updateLiveBatteryPackage(self.view, safeLevel);
    }
}

%end

#pragma clang diagnostic pop
