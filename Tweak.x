#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@property (nonatomic, retain) UILabel *cowbellLabel;
@property (nonatomic, readonly, assign, getter=isExpanded) BOOL expanded;
- (void)updateCowbellState;
@end

@interface CCUIContentModuleContentContainerView : UIView
@end

%hook CCUIContentModuleContainerViewController
%property (nonatomic, retain) UILabel *cowbellLabel;

%new
- (void)updateCowbellState {
    if (!self.cowbellLabel) return;

    // 1. 二级菜单展开时隐形
    if (self.isExpanded) {
        self.cowbellLabel.hidden = YES;
        return;
    }
    self.cowbellLabel.hidden = NO;

    // 2. 读取电量
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
    [self.cowbellLabel sizeToFit];
    [self.view bringSubviewToFront:self.cowbellLabel];

    // 3. 禁用隐式动画，防止切回一级菜单时文字飞跃
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    CGFloat viewW = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : 72.0;
    CGFloat viewH = self.view.bounds.size.height > 0 ? self.view.bounds.size.height : 72.0;
    CGFloat labelW = self.cowbellLabel.frame.size.width;
    CGFloat labelH = self.cowbellLabel.frame.size.height;

    self.cowbellLabel.frame = CGRectMake(
        (viewW - labelW) / 2.0,
        viewH * 0.72 - (labelH / 2.0),
        labelW,
        labelH
    );

    // 4. 读取当前系统的低电量开关状态
    BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    if (isLPMOn) {
        self.cowbellLabel.layer.compositingFilter = kCAFilterDestOut;
    } else {
        self.cowbellLabel.layer.compositingFilter = nil;
    }

    [CATransaction commit];
}

- (void)viewDidLoad {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        if (!self.cowbellLabel) {
            UILabel *label = [[UILabel alloc] init];
            label.textColor = [UIColor whiteColor];
            label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
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

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [self updateCowbellState];
    }
}

- (void)willTransitionToExpandedContentMode:(BOOL)expanded {
    %orig(expanded);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        if (self.cowbellLabel) {
            self.cowbellLabel.hidden = expanded;
            if (!expanded) {
                [self updateCowbellState];
            }
        }
    }
}

%end

// 关键点：Hook 低电量模块内部的实际 View 绘制入口
// 点击按钮切换状态时，系统必定会调用这个 View 的 layoutSubviews 或 setNeedsLayout
%hook CCUIContentModuleContentContainerView

- (void)layoutSubviews {
    %orig;

    // 向上寻找 ContainerViewController 强制刷新 Label
    for (UIResponder *r = self; r; r = r.nextResponder) {
        if ([r isKindOfClass:NSClassFromString(@"CCUIContentModuleContainerViewController")]) {
            CCUIContentModuleContainerViewController *vc = (CCUIContentModuleContainerViewController *)r;
            if ([vc.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
                // 确保在系统修改完 isLowPowerModeEnabled 后的下一帧刷新
                dispatch_async(dispatch_get_main_queue(), ^{
                    [vc updateCowbellState];
                });
            }
            break;
        }
    }
}

%end

#pragma clang diagnostic pop
