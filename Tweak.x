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
@property (nonatomic, retain) NSLayoutConstraint *topConstraint; // 声明顶部约束引用
@property (nonatomic, readonly, assign, getter=isExpanded) BOOL expanded;
- (UIView *)contentView;
- (void)updateCowbellState;
@end

%hook CCUIContentModuleContainerViewController
%property (nonatomic, retain) UILabel *cowbellLabel;
%property (nonatomic, retain) NSLayoutConstraint *topConstraint;

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

    // 2. 状态变色（防止纯镂空在特定背景下识别度低）
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

            // 保持 Cowbell 灵魂镂空
            CAFilter *filter = [CAFilter filterWithType:kCAFilterDestOut];
            label.layer.filters = @[filter];

            // 开启 AutoLayout
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [targetContainer addSubview:label];
            self.cowbellLabel = label;

            // 改为锚定 topAnchor，保证跟手且不会跑偏到底部
            // 默认一级卡片：距离顶部 40pt（正好在小电池下半部分）
            NSLayoutConstraint *centerX = [label.centerXAnchor constraintEqualToAnchor:targetContainer.centerXAnchor];
            NSLayoutConstraint *top = [label.topAnchor constraintEqualToAnchor:targetContainer.topAnchor constant:40.0];

            self.topConstraint = top;
            [NSLayoutConstraint activateConstraints:@[centerX, top]];
        }

        // 根据展开状态更新 topAnchor 的偏移量
        BOOL isExpandedState = NO;
        if ([self respondsToSelector:@selector(isExpanded)]) {
            isExpandedState = self.expanded;
        }

        // 一级状态为 40.0，二级展开状态为 68.0（大电池下方）
        CGFloat targetConstant = isExpandedState ? 68.0 : 40.0;
        if (self.topConstraint && self.topConstraint.constant != targetConstant) {
            self.topConstraint.constant = targetConstant;
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

// 展开/收起转场时，跟随系统的 CoreAnimation 视图拉伸同步更新约束
- (void)willTransitionToExpandedContentMode:(BOOL)expanded {
    %orig(expanded);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        if (!self.cowbellLabel || !self.topConstraint) return;

        // 展开设置为 68.0，收起恢复 40.0
        self.topConstraint.constant = expanded ? 68.0 : 40.0;

        [UIView animateWithDuration:0.3 animations:^{
            [self.view layoutIfNeeded];
        }];
    }
}

%end

#pragma clang diagnostic pop
