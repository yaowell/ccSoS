#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

extern NSString* const kCAFilterDestOut;

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUILowPowerModuleViewController : UIViewController
@property (nonatomic, retain) UILabel *cowbellLabel;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@end

// 辅助函数：递归寻找子视图中的 CCUICAPackageView
static UIView *findPackageView(UIView *view) {
    if (!view) return nil;
    if ([NSStringFromClass([view class]) containsString:@"CCUICAPackageView"]) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *found = findPackageView(subview);
        if (found) return found;
    }
    return nil;
}

%hook CCUILowPowerModuleViewController
%property (nonatomic, retain) UILabel *cowbellLabel;

- (void)viewDidLayoutSubviews {
    %orig;

    // 找到真正的图标渲染容器 CCUICAPackageView
    UIView *packageView = findPackageView(self.view);
    if (!packageView) return;

    if (!self.cowbellLabel) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        UILabel *label = [[UILabel alloc] init];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;

        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;

        [packageView addSubview:label];
        self.cowbellLabel = label;
    }

    // 确定父容器存在且正常加载
    if (self.cowbellLabel && self.cowbellLabel.superview) {
        float level = [UIDevice currentDevice].batteryLevel;
        int battery = (level < 0) ? 100 : (int)round(level * 100);
        self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.cowbellLabel sizeToFit];

        // 基于 packageView 的真实尺寸进行相对居中定位
        CGFloat w = packageView.bounds.size.width;
        CGFloat h = packageView.bounds.size.height;
        if (w > 0 && h > 0) {
            self.cowbellLabel.center = CGPointMake(w / 2.0, h * 0.72);
        }

        // 获取按钮选中状态，同步滤镜
        BOOL isSelected = NO;
        if ([self respondsToSelector:@selector(isSelected)]) {
            isSelected = [self isSelected];
        }

        self.cowbellLabel.layer.compositingFilter = isSelected ? kCAFilterDestOut : nil;
        [packageView bringSubviewToFront:self.cowbellLabel];
    }
}

%end
