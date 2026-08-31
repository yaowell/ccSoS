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

%hook CCUIContentModuleContainerViewController
%property (nonatomic, retain) UILabel *cowbellLabel;

%new
- (void)updateCowbellState {
    if (!self.cowbellLabel) return;

    // 二级菜单展开时隐形，防止布局变形
    if (self.isExpanded) {
        self.cowbellLabel.hidden = YES;
        return;
    }
    self.cowbellLabel.hidden = NO;

    // 1. 读取电量
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
    [self.cowbellLabel sizeToFit];
    [self.view bringSubviewToFront:self.cowbellLabel];

    // 2. 禁用隐式动画，防止切回一级菜单时百分比“飞跃”
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

    // 3. 原版 Cowbell 滤镜逻辑：
    //    低电量开启（背景黄）：应用 kCAFilterDestOut 镂空成黑色
    //    低电量关闭（背景灰）：必须将 compositingFilter 设为 nil，恢复普通白色！
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

// 首次出现与布局更新时刷新
- (void)viewDidLayoutSubviews {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [self updateCowbellState];
    }
}

// 捕获一级/二级菜单转场
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

// 关键点：Hook 模块手势响应（零 Notification！纯靠点击事件驱动）
- (void)_handleTapGestureRecognizer:(UIGestureRecognizer *)recognizer {
    %orig(recognizer);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        // 延时 0.05 秒，确保系统的 isLowPowerModeEnabled 状态完成切换后立刻更新滤镜
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self updateCowbellState];
        });
    }
}

%end

#pragma clang diagnostic pop
