#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@property (nonatomic, retain) UILabel *cowbellLabel;
@property (nonatomic, retain) NSLayoutConstraint *bottomConstraint; // 底部约束引用
@property (nonatomic, readonly, assign, getter=isExpanded) BOOL expanded;
- (UIView *)contentView;
- (void)updateCowbellState;
@end

%hook CCUIContentModuleContainerViewController
%property (nonatomic, retain) UILabel *cowbellLabel;
%property (nonatomic, retain) NSLayoutConstraint *bottomConstraint;

%new
- (void)updateCowbellState {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCowbellState];
        });
        return;
    }

    if (!self.cowbellLabel) return;

    // 1. 读取并更新文本
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);
    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];

    // 2. 状态变色
    BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    self.cowbellLabel.textColor = isLPMOn ? [UIColor blackColor] : [UIColor whiteColor];
}

- (void)viewDidLoad {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        UIView *targetContainer = [self respondsToSelector:@selector(contentView)] ? [self contentView] : self.view;

        if (!self.cowbellLabel && targetContainer) {
            UILabel *label = [[UILabel alloc] init];
            label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
            label.textAlignment = NSTextAlignmentCenter;
            label.userInteractionEnabled = NO;

            label.backgroundColor = [UIColor clearColor];
            label.textColor = [UIColor whiteColor];

            // 保持 Cowbell 经典镂空效果
            CAFilter *filter = [CAFilter filterWithType:kCAFilterDestOut];
            label.layer.filters = @[filter];

            // 重新开启 AutoLayout 约束，保证跟随系统 3D 矩阵一同缩放
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [targetContainer addSubview:label];
            self.cowbellLabel = label;

            NSLayoutConstraint *centerX = [label.centerXAnchor constraintEqualToAnchor:targetContainer.centerXAnchor];
            // 默认一级菜单底部向上偏移 -6.0
            NSLayoutConstraint *bottom = [label.bottomAnchor constraintEqualToAnchor:targetContainer.bottomAnchor constant:-6.0];
            self.bottomConstraint = bottom;

            [NSLayoutConstraint activateConstraints:@[centerX, bottom]];
        }

        // 根据当前是否展开，实时赋予对应的约束偏移量
        BOOL isExpandedState = NO;
        if ([self respondsToSelector:@selector(isExpanded)]) {
            isExpandedState = self.expanded;
        }

        CGFloat targetConstant = isExpandedState ? -145.0 : -6.0; // -145 对应二级大电池下方，可根据实际视觉微调
        if (self.bottomConstraint && self.bottomConstraint.constant != targetConstant) {
            self.bottomConstraint.constant = targetConstant;
        }

        [self updateCowbellState];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [nc removeObserver:self name:UIDeviceBatteryLevelDidChangeNotification object:nil];

        [nc addObserver:self selector:@selector(updateCowbellState) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(updateCowbellState) name:UIDeviceBatteryLevelDidChangeNotification object:nil];

        [self updateCowbellState];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [nc removeObserver:self name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    }
}

// 核心：在系统转场时，通过约束平滑过度，既保证跟手缩放，又让位置随着动画精准推到大电池下方
- (void)willTransitionToExpandedContentMode:(BOOL)expanded {
    %orig(expanded);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        if (!self.cowbellLabel || !self.bottomConstraint) return;

        // 展开时推到 -145.0（大电池下方），收起时恢复 -6.0
        self.bottomConstraint.constant = expanded ? -145.0 : -6.0;

        [UIView animateWithDuration:0.35 animations:^{
            [self.view layoutIfNeeded];
        }];
    }
}

%end

#pragma clang diagnostic pop
