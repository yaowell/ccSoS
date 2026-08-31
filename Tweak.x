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
@property (nonatomic, readonly, assign, getter=isExpanded) BOOL expanded;
- (UIView *)contentView;
- (void)updateCowbellState;
@end

%hook CCUIContentModuleContainerViewController
%property (nonatomic, retain) UILabel *cowbellLabel;

%new
- (void)updateCowbellState {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCowbellState];
        });
        return;
    }

    if (!self.cowbellLabel) return;

    // 1. 判断是否展开（二级菜单模式）：展开时强制彻底隐藏
    BOOL isExpandedState = NO;
    if ([self respondsToSelector:@selector(isExpanded)]) {
        isExpandedState = self.expanded;
    }

    UIView *targetContainer = [self respondsToSelector:@selector(contentView)] ? [self contentView] : self.view;
    CGFloat parentH = targetContainer.bounds.size.height;

    if (isExpandedState || parentH > 100.0) {
        self.cowbellLabel.hidden = YES;
        self.cowbellLabel.alpha = 0.0;
        return;
    }

    // 2. 一级菜单状态：显示并刷新文本
    self.cowbellLabel.hidden = NO;
    self.cowbellLabel.alpha = 1.0;

    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);
    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];

    // 3. 状态变色
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

            // 保持 Cowbell 镂空
            CAFilter *filter = [CAFilter filterWithType:kCAFilterDestOut];
            label.layer.filters = @[filter];

            label.translatesAutoresizingMaskIntoConstraints = NO;
            [targetContainer addSubview:label];
            self.cowbellLabel = label;

            // 自动布局定位
            [NSLayoutConstraint activateConstraints:@[
                [label.centerXAnchor constraintEqualToAnchor:targetContainer.centerXAnchor],
                [label.bottomAnchor constraintEqualToAnchor:targetContainer.bottomAnchor constant:-6.0]
            ]];
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

// 展开/收起转场处理：瞬间将 alpha 和 hidden 组合拦截，不给它在二级菜单露脸的机会
- (void)willTransitionToExpandedContentMode:(BOOL)expanded {
    %orig(expanded);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        if (!self.cowbellLabel) return;

        if (expanded) {
            self.cowbellLabel.hidden = YES;
            self.cowbellLabel.alpha = 0.0;
        } else {
            self.cowbellLabel.hidden = NO;
            self.cowbellLabel.alpha = 1.0;
            [self updateCowbellState];
        }
    }
}

%end

#pragma clang diagnostic pop
