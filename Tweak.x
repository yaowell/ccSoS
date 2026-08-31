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

@interface CCUICAPackageView : UIView
- (void)setStateName:(NSString *)stateName;
- (void)setPropertyValue:(id)value forKeyPath:(NSString *)keyPath;
@end

// iOS 16 控制中心模块容器类
@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@property (nonatomic, retain) UILabel *cowbellLabel;
@end

// 驱动系统原生 CCUICAPackageView，实现 Live Battery Indicator (电量实时随动)
static void updateLiveBatteryPackage(UIView *view, float batteryLevel) {
    if (!view) return;

    if ([NSStringFromClass([view class]) containsString:@"CCUICAPackageView"]) {
        CCUICAPackageView *packageView = (CCUICAPackageView *)view;
        
        // 1. 尝试直接驱动系统 PackageView 的 KeyPath 状态
        [packageView setPropertyValue:@(batteryLevel) forKeyPath:@"batteryLevel"];
        [packageView setPropertyValue:@(batteryLevel) forKeyPath:@"level"];

        // 2. CoreAnimation 图层时间轴备用锁定方案
        CALayer *packageLayer = view.layer;
        NSMutableArray *layers = [NSMutableArray arrayWithObject:packageLayer];
        while (layers.count > 0) {
            CALayer *l = [layers firstObject];
            [layers removeObjectAtIndex:0]; // 已修正变量名错误

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

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

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
        
        float level = [[UIDevice currentDevice] batteryLevel];
        float safeLevel = (level < 0) ? 1.0 : level;
        int battery = (int)round(safeLevel * 100);

        // 1. 刷新百分比
        self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.cowbellLabel sizeToFit];

        [self.view bringSubviewToFront:self.cowbellLabel];

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

        // 2. 镂空反色
        BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
        if (isLPMOn) {
            self.cowbellLabel.layer.compositingFilter = kCAFilterDestOut;
        } else {
            self.cowbellLabel.layer.compositingFilter = nil;
        }

        // 3. 复刻 Live Battery Indicator 实时动画
        updateLiveBatteryPackage(self.view, safeLevel);
    }
}

%end

#pragma clang diagnostic pop
