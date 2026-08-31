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

    // 1. 二级菜单展开时隐形
    if (self.isExpanded) {
        self.cowbellLabel.hidden = YES;
        return;
    }
    self.cowbellLabel.hidden = NO;

    // 2. 获取电量
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
    [self.cowbellLabel sizeToFit];
    [self.view bringSubviewToFront:self.cowbellLabel];

    // 3. 禁用隐式动画
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

    // 4. 实时判定系统低电量状态并更新 GPU 滤镜
    BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    self.cowbellLabel.layer.compositingFilter = isLPMOn ? kCAFilterDestOut : nil;

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

// 关键修复：直接 Hook 控制中心低电量 Module 自身的点击动作入口
%hook CCUILowPowerModule

- (void)setSelected:(BOOL)selected {
    %orig(selected);

    // 点击发生的瞬间，通知容器 VC 主动刷新滤镜
    UIViewController *contentVC = (UIViewController *)self;
    UIViewController *parentVC = contentVC.parentViewController;

    // 向上寻找 ContainerViewController
    while (parentVC && ![parentVC isKindOfClass:NSClassFromString(@"CCUIContentModuleContainerViewController")]) {
        parentVC = parentVC.parentViewController;
    }

    if ([parentVC isKindOfClass:NSClassFromString(@"CCUIContentModuleContainerViewController")]) {
        CCUIContentModuleContainerViewController *containerVC = (CCUIContentModuleContainerViewController *)parentVC;
        dispatch_async(dispatch_get_main_queue(), ^{
            [containerVC updateCowbellState];
        });
    }
}

%end

#pragma clang diagnostic pop
