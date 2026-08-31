#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

// 声明系统的圆角按钮类（一级 1x1 卡片的真正视图）
@interface CCUIRoundButton : UIView
@property (nonatomic, retain) UILabel *cowbellLabel;
- (void)updateCowbellState;
@end

@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@end

#pragma mark - Hook 真正的一级图标按钮 (CCUIRoundButton)

%hook CCUIRoundButton
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

    // 2. 状态变色（低电量模式下为黑色，常规为白色）
    BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    self.cowbellLabel.textColor = isLPMOn ? [UIColor blackColor] : [UIColor whiteColor];
}

- (void)layoutSubviews {
    %orig;

    // 确保仅在低电量模块内部作用，避免影响其他控制中心按钮
    UIResponder *responder = self;
    BOOL isLowPowerModule = NO;
    while ((responder = responder.nextResponder)) {
        if ([responder isKindOfClass:[CCUIContentModuleContainerViewController class]]) {
            CCUIContentModuleContainerViewController *vc = (CCUIContentModuleContainerViewController *)responder;
            if ([vc.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
                isLowPowerModule = YES;
            }
            break;
        }
    }

    if (!isLowPowerModule) return;

    // 初始化 Label 并添加为 CCUIRoundButton 的直接子视图
    if (!self.cowbellLabel) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];

        // 保留经典的 Cowbell 镂空效果
        CAFilter *filter = [CAFilter filterWithType:kCAFilterDestOut];
        label.layer.filters = @[filter];

        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:label];
        self.cowbellLabel = label;

        // 精准锚定在 1x1 按钮的正下方（距离按钮底边向上 6pt，完美居中绝不上移/下掉）
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6.0]
        ]];

        // 绑定电量变化通知
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(updateCowbellState) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(updateCowbellState) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    }

    [self updateCowbellState];
}

%end

#pragma clang diagnostic pop
