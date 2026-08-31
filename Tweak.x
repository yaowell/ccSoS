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

@interface CCUIRoundButton : UIView
@property (nonatomic, retain) UILabel *cowbellLabel;
- (void)updateCowbellLabelState;
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

    // 1. 读取电量
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
    [self.cowbellLabel sizeToFit];

    // 2. 禁用隐式动画，防止重绘闪烁
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    CGFloat viewW = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : 72.0;
    CGFloat viewH = self.view.bounds.size.height > 0 ? self.view.bounds.size.height : 72.0;
    CGFloat labelW = self.cowbellLabel.frame.size.width;
    CGFloat labelH = self.cowbellLabel.frame.size.height;

    // 定位在图标正下方
    self.cowbellLabel.frame = CGRectMake(
        (viewW - labelW) / 2.0,
        viewH * 0.72 - (labelH / 2.0),
        labelW,
        labelH
    );

    // 3. 同步颜色切换（低电量高亮为黑字，非低电量为纯白字）
    BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    self.cowbellLabel.textColor = isLPMOn ? [UIColor blackColor] : [UIColor whiteColor];

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
            label.userInteractionEnabled = NO;

            [self.view addSubview:label];
            self.cowbellLabel = label;
        }
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

- (void)viewDidLayoutSubviews {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [self updateCowbellState];
    }
}

// 核心修复：二级菜单展开时，将 Label 完全隐形，消除展开后下方透出文字的问题
- (void)willTransitionToExpandedContentMode:(BOOL)expanded {
    %orig(expanded);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        if (self.cowbellLabel) {
            // 展开时立即隐藏，收起时恢复
            self.cowbellLabel.hidden = expanded;
            if (!expanded) {
                [self updateCowbellState];
            }
        }
    }
}

%end

#pragma clang diagnostic pop
