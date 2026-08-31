#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface NSObject (Private)
- (BOOL)isSelected;
@end

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUIToggleViewController : UIViewController
@property (nonatomic, assign) BOOL isLowPowerModule;
@property (nonatomic, retain) UILabel *percentLabel;
@property (nonatomic, retain) NSObject *module;
- (void)refreshState;
@end

// 递归给 PackageView 整体打上红/黄/白滤镜，并动态改变 X 轴缩放（代表容量）
static void applyBatteryStyle(UIView *view, float level, BOOL isSelected) {
    if (!view) return;

    if ([NSStringFromClass([view class]) containsString:@"CCUICAPackageView"]) {
        CALayer *layer = view.layer;
        int battery = (int)round(level * 100);

        // 1. 容量跟着变：安全微调 X 轴缩放比例 (保持最小 0.2，避免完全缩不见)
        CGFloat scaleX = 0.2 + (0.8 * level);
        layer.transform = CATransform3DMakeScale(scaleX, 1.0, 1.0);

        // 2. 低电量变红逻辑
        if (!isSelected && battery <= 20) {
            // 强行把图标颜色染色成系统警告红 (Red Tint)
            view.tintColor = [UIColor systemRedColor];
        } else {
            // 恢复系统默认
            view.tintColor = nil;
        }
        return;
    }

    for (UIView *subview in view.subviews) {
        applyBatteryStyle(subview, level, isSelected);
    }
}

%hook CCUIToggleViewController
%property (nonatomic, assign) BOOL isLowPowerModule;
%property (nonatomic, retain) UILabel *percentLabel;

- (void)viewDidLoad {
    %orig;

    if ([self.module isKindOfClass:NSClassFromString(@"CCUILowPowerModule")]) {
        self.isLowPowerModule = YES;
    }

    if (self.isLowPowerModule) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        // Cowbell 原版百分比 Label
        UILabel *label = [[UILabel alloc] init];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;
        label.layer.compositingFilter = kCAFilterDestOut;

        [self.view addSubview:label];
        self.percentLabel = label;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);

    if (self.isLowPowerModule && self.percentLabel) {
        float level = [[UIDevice currentDevice] batteryLevel];
        float safeLevel = (level < 0) ? 1.0 : level;
        int battery = (int)round(safeLevel * 100);

        // 百分比文字
        self.percentLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.percentLabel sizeToFit];

        CGFloat viewW = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : 72.0;
        CGFloat viewH = self.view.bounds.size.height > 0 ? self.view.bounds.size.height : 72.0;
        
        self.percentLabel.frame = CGRectMake(
            (viewW - self.percentLabel.frame.size.width) / 2.0,
            viewH * 0.70,
            self.percentLabel.frame.size.width,
            self.percentLabel.frame.size.height
        );

        [self refreshState];
    }
}

- (void)refreshState {
    %orig;

    if (self.isLowPowerModule && self.percentLabel) {
        BOOL isSelected = [self.module isSelected];
        float level = [[UIDevice currentDevice] batteryLevel];
        float safeLevel = (level < 0) ? 1.0 : level;

        // 1. 切换文字镂空状态
        if (isSelected) {
            self.percentLabel.layer.compositingFilter = kCAFilterDestOut;
        } else {
            self.percentLabel.layer.compositingFilter = nil;
        }

        // 2. 刷新电池图标的缩放与红变
        applyBatteryStyle(self.view, safeLevel, isSelected);
    }
}

%end

#pragma clang diagnostic pop
