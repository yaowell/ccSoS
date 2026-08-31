#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

extern NSString* const kCAFilterDestOut;

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUIRoundButton : UIView
@property (nonatomic, assign) BOOL selected;
@end

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

static char kCowbellLabelKey;
static char kIsLowPowerKey;

// 1. 在低电量图标的包裹容器中注入镂空 Label
%hook CCUICAPackageView

- (void)layoutSubviews {
    %orig;

    // 缓存模块判断，避免每次 layout 重复匹配
    NSNumber *isLowPower = objc_getAssociatedObject(self, &kIsLowPowerKey);
    if (!isLowPower) {
        BOOL matched = NO;
        NSString *pkgName = [self respondsToSelector:@selector(packageName)] ? self.packageName : @"";
        if ([pkgName containsString:@"LowPower"] || [pkgName containsString:@"Battery"]) {
            matched = YES;
        } else {
            for (UIResponder *r = self; r; r = r.nextResponder) {
                NSString *cls = NSStringFromClass([r class]);
                if ([cls containsString:@"LowPower"]) {
                    matched = YES;
                    break;
                }
            }
        }
        isLowPower = @(matched);
        objc_setAssociatedObject(self, &kIsLowPowerKey, isLowPower, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!isLowPower.boolValue) return;

    UILabel *label = objc_getAssociatedObject(self, &kCowbellLabelKey);
    if (!label) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        label = [[UILabel alloc] init];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;

        // 原版 Cowbell 核心：GPU 混合镂空
        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;
        label.layer.compositingFilter = kCAFilterDestOut;

        [self addSubview:label];
        objc_setAssociatedObject(self, &kCowbellLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // 实时更新电量
    float level = [UIDevice currentDevice].batteryLevel;
    int battery = (level < 0) ? 100 : (int)round(level * 100);
    label.text = [NSString stringWithFormat:@"%i%%", battery];
    [label sizeToFit];

    // 居中靠下摆放
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    label.center = CGPointMake(w / 2.0, h * 0.72);
}

%end

// 2. 监听圆按钮点击状态，动态切换镂空滤镜
%hook CCUIRoundButton

- (void)setSelected:(BOOL)selected {
    %orig(selected);

    // 遍历子视图寻找并切换 Cowbell Label 的滤镜
    for (UIView *subview in self.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"CCUICAPackageView"]) {
            UILabel *label = objc_getAssociatedObject(subview, &kCowbellLabelKey);
            if (label) {
                // 开启低电量（黄色/白色背景）时使用 kCAFilterDestOut 镂空；未开启时正常显示白字
                label.layer.compositingFilter = selected ? kCAFilterDestOut : nil;
            }
        }
    }
}

%end
