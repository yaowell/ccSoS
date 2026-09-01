#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString *const kCAFilterDestOut;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
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

// 刷新电量数值（仅负责数字，不改变颜色）
static void CowbellUpdatePercent(CCUICAPackageView *view) {
    if (!view) return;
    UILabel *label = CowbellGetLabel(view);
    if (!label || !label.window) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!label.window) return;

        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }

        float level = UIDevice.currentDevice.batteryLevel;
        if (level < 0) level = 1.0f;
        int percent = (int)round(level * 100.0f);

        label.text = [NSString stringWithFormat:@"%d%%", percent];
        [label setNeedsLayout];
    });
}

// 创建并初始化 Label，滤镜永久生效
static UILabel *CowbellCreateLabel(CCUICAPackageView *view) {
    UILabel *label = CowbellGetLabel(view);
    if (label) return label;

    label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;
    label.backgroundColor = [UIColor clearColor];
    
    // 固定的白色基础色，配合 DestOut 混合模式
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];

    // 允许图层组混合与不透明度控制
    label.layer.allowsGroupBlending = YES;
    label.layer.allowsGroupOpacity = YES;

    // 永久挂载 DestOut 镂空滤镜，无需代码在开启/关闭时手动切换
    CAFilter *filter = [CAFilter filterWithType:kCAFilterDestOut];
    label.layer.filters = @[filter];
    label.tag = 9998;

    [view addSubview:label];

    objc_setAssociatedObject(view, &kCowbellPercentLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 保留电量变化的广播监听
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        CowbellUpdatePercent(view);
    }];

    return label;
}

%hook CCUICAPackageView

- (void)layoutSubviews {
    %orig;

    if (!CowbellIsLowPowerPackage(self)) return;

    if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    }

    UILabel *label = CowbellCreateLabel(self);
    if (!label) return;

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0) return;

    CGFloat centerY = height * 0.5f;
    CGFloat y = centerY + COWBELL_PERCENT_Y_OFFSET;

    label.frame = CGRectMake(0, y, width, 11.0f);
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];

    // 确保文字位于图标背景图层的上方
    [self bringSubviewToFront:label];
    CowbellUpdatePercent(self);
}

- (void)didMoveToWindow {
    %orig;

    if (!CowbellIsLowPowerPackage(self)) return;

    if (self.window) {
        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }

        UILabel *label = CowbellGetLabel(self);
        if (label) {
            label.hidden = NO;
            label.alpha = 1.0f;
            CowbellUpdatePercent(self);
        }
    }
}

%end

#pragma clang diagnostic pop
