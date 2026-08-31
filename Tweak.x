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
@property (nonatomic, retain) NSLayoutConstraint *bottomConstraint;
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

    // 1. 读取并刷新电量
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);
    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];

    // 2. 状态变色（保持一致）
    BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    self.cowbellLabel.textColor = isLPMOn ? [UIColor blackColor] : [UIColor whiteColor];

    // 3. 动态更新约束值（根据展开状态适配偏移）
    BOOL isExpandedState = NO;
    if ([self respondsToSelector:@selector(isExpanded)]) {
        isExpandedState = self.expanded;
    }

    // 二级菜单大卡片往上推到大电池下方 (-38pt)，一级小卡片保持在底部 (-6pt)
    CGFloat targetOffset = isExpandedState ? -38.0 : -6.0;
    if (self.bottomConstraint && self.bottomConstraint.constant != targetOffset) {
        self.bottomConstraint.constant = targetOffset;
    }
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

            label.translatesAutoresizingMaskIntoConstraints = NO;
            [targetContainer addSubview:label];
            self.cowbellLabel = label;

            // 创建约束并保存 bottomConstraint 的引用
            NSLayoutConstraint *centerX = [label.centerXAnchor constraintEqualToAnchor:targetContainer.centerXAnchor];
            NSLayoutConstraint *bottom = [label.bottomAnchor constraintEqualToAnchor:targetContainer.bottomAnchor constant:-6.0];

            self.bottomConstraint = bottom;
            [NSLayoutConstraint activateConstraints:@[centerX, bottom]];
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

// 在转场动画过程中平滑切换约束，全程不隐藏，实现 100% 同步跟手
- (void)willTransitionToExpandedContentMode:(BOOL)expanded {
    %orig(expanded);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        if (!self.bottomConstraint) return;

        // 展开时偏移 -38.0（大电池正下方），收起时偏移 -6.0（小电池正下方）
        self.bottomConstraint.constant = expanded ? -38.0 : -6.0;

        // 让 UIView 动画闭包跟着系统转场一起做 Layout 动画
        [UIView animateWithDuration:0.35 animations:^{
            [self.view layoutIfNeeded];
        }];
    }
}

%end

#pragma clang diagnostic pop
