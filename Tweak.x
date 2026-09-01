#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@property (nonatomic, copy) NSString *state;
@end

static char kCowbellPercentLabelKey;
static char kCowbellIsLowPowerKey;

static CGFloat const COWBELL_PERCENT_Y_OFFSET = 12.0;

static UILabel *CowbellGetLabel(CCUICAPackageView *view) {
    return objc_getAssociatedObject(view, &kCowbellPercentLabelKey);
}

// 识别是否为低电量模式图标
static BOOL CowbellIsLowPowerPackage(CCUICAPackageView *view) {
    NSNumber *cached = objc_getAssociatedObject(view, &kCowbellIsLowPowerKey);
    if (cached) return cached.boolValue;

    BOOL matched = NO;
    NSString *pkgName = @"";
    if ([view respondsToSelector:@selector(packageName)]) {
        pkgName = view.packageName ?: @"";
    }

    if ([pkgName containsString:@"LowPower"] || [pkgName containsString:@"Battery"]) {
        matched = YES;
    }

    if (!matched) {
        for (UIResponder *r = view; r; r = [r nextResponder]) {
            NSString *cls = NSStringFromClass([r class]);
            if ([cls containsString:@"Brightness"] || [cls containsString:@"Display"]) break;
            if ([cls containsString:@"LowPower"]) {
                matched = YES;
                break;
            }
        }
    }

    objc_setAssociatedObject(view, &kCowbellIsLowPowerKey, @(matched), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return matched;
}

// 读取当前系统电量并更新显示文本
static void CowbellUpdatePercent(CCUICAPackageView *view) {
    if (!view) return;
    UILabel *label = CowbellGetLabel(view);
    if (!label || !label.window) return;

    if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    }

    float level = UIDevice.currentDevice.batteryLevel;
    if (level < 0) level = 1.0f;
    int percent = (int)round(level * 100.0f);

    label.text = [NSString stringWithFormat:@"%d%%", percent];
    [label setNeedsLayout];
}

// 判断当前 packageState 是否为激活/开启状态
static BOOL CowbellIsStateActive(NSString *state) {
    if (!state) return NO;
    NSString *s = [state lowercaseString];
    return [s containsString:@"on"] || [s containsString:@"selected"] || [s containsString:@"active"] || [s containsString:@"yellow"];
}

// 根据 state 刷新文字颜色
static void CowbellUpdateColorForState(CCUICAPackageView *view, NSString *state) {
    UILabel *label = CowbellGetLabel(view);
    if (!label) return;

    BOOL isActive = CowbellIsStateActive(state);
    label.textColor = isActive ? [UIColor blackColor] : [UIColor whiteColor];
}

// 创建并初始化 Label（不含 Notification 监听）
static UILabel *CowbellCreateLabel(CCUICAPackageView *view) {
    UILabel *label = CowbellGetLabel(view);
    if (label) return label;

    label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];
    label.tag = 9998;

    [view addSubview:label];

    objc_setAssociatedObject(view, &kCowbellPercentLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return label;
}

%hook CCUICAPackageView

// 1. Hook 系统的 setState: 方法，点击图标时切换状态会触发
- (void)setState:(NSString *)state {
    %orig(state);

    if (CowbellIsLowPowerPackage(self)) {
        CowbellUpdateColorForState(self, state);
    }
}

// 2. Hook setState:animated: 防备部分切换带动画调用的情况
- (void)setState:(NSString *)state animated:(BOOL)animated {
    %orig(state, animated);

    if (CowbellIsLowPowerPackage(self)) {
        CowbellUpdateColorForState(self, state);
    }
}

- (void)layoutSubviews {
    %orig;

    if (!CowbellIsLowPowerPackage(self)) return;

    UILabel *label = CowbellCreateLabel(self);
    if (!label) return;

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0) return;

    CGFloat centerY = height * 0.5f;
    CGFloat y = centerY + COWBELL_PERCENT_Y_OFFSET;

    label.frame = CGRectMake(0, y, width, 11.0f);
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];

    [self bringSubviewToFront:label];

    // 绘制布局时同步一次当前状态颜色与电量
    if ([self respondsToSelector:@selector(state)]) {
        CowbellUpdateColorForState(self, self.state);
    }
    CowbellUpdatePercent(self);
}

- (void)didMoveToWindow {
    %orig;

    if (!CowbellIsLowPowerPackage(self)) return;

    if (self.window) {
        UILabel *label = CowbellGetLabel(self);
        if (label) {
            label.hidden = NO;
            label.alpha = 1.0f;
            
            // 下拉控制中心进入屏幕时，只在此时更新一次颜色和电量
            if ([self respondsToSelector:@selector(state)]) {
                CowbellUpdateColorForState(self, self.state);
            }
            CowbellUpdatePercent(self);
        }
    }
}

%end

#pragma clang diagnostic pop
