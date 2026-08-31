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

// 递归寻找视图链中的 CCUIButtonModuleView
static UIView *findButtonModuleView(UIView *view) {
    if (!view) return nil;
    if ([NSStringFromClass([view class]) containsString:@"CCUIButtonModuleView"]) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *found = findButtonModuleView(subview);
        if (found) return found;
    }
    return nil;
}

%hook CCUILowPowerModuleViewController
%property (nonatomic, retain) UILabel *cowbellLabel;

- (void)viewDidLayoutSubviews {
    %orig;

    // 寻找按钮层 CCUIButtonModuleView，若找不到则直接降级取 self.view
    UIView *targetContainer = findButtonModuleView(self.view);
    if (!targetContainer) targetContainer = self.view;

    if (!self.cowbellLabel) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        UILabel *label = [[UILabel alloc] init];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;

        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;

        [targetContainer addSubview:label];
        self.cowbellLabel = label;
    }

    if (self.cowbellLabel) {
        // 防止被父视图裁剪
        targetContainer.clipsToBounds = NO;
        self.view.clipsToBounds = NO;

        // 强行把 Label 提至顶层
        [targetContainer bringSubviewToFront:self.cowbellLabel];

        // 获取电量
        float level = [UIDevice currentDevice].batteryLevel;
        int battery = (level < 0) ? 100 : (int)round(level * 100);
        self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.cowbellLabel sizeToFit];

        // 绝对定位：放置在 72x72 方块的正下方空隙处
        CGFloat w = targetContainer.bounds.size.width;
        CGFloat h = targetContainer.bounds.size.height;

        if (w > 0 && h > 0) {
            self.cowbellLabel.center = CGPointMake(w / 2.0, h * 0.72);
        } else {
            // 降级兜底坐标
            self.cowbellLabel.center = CGPointMake(36.0, 52.0);
        }

        // 判断选中状态
        BOOL isSelected = NO;
        if ([self respondsToSelector:@selector(isSelected)]) {
            isSelected = [self isSelected];
        }

        // 开启低电量（黄/白底）时使用 GPU 混合镂空；未开启时正常白字
        self.cowbellLabel.layer.compositingFilter = isSelected ? kCAFilterDestOut : nil;
    }
}

%end
