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

    // 1. 读取并更新文本
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];

    // 2. 状态变色
    BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];

    self.cowbellLabel.textColor =
        isLPMOn ? [UIColor blackColor] : [UIColor whiteColor];
}

- (void)viewDidLoad {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (![self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        return;
    }

    UIView *targetContainer =
        [self respondsToSelector:@selector(contentView)]
        ? [self contentView]
        : self.view;

    if (!targetContainer) return;

    if (!self.cowbellLabel) {

        UILabel *label = [[UILabel alloc] init];

        label.font =
            [UIFont systemFontOfSize:10 weight:UIFontWeightBold];

        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;

        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];

        // 保持 Cowbell 灵魂镂空
        CAFilter *filter =
            [CAFilter filterWithType:kCAFilterDestOut];

        label.layer.filters = @[filter];

        // AutoLayout
        label.translatesAutoresizingMaskIntoConstraints = NO;

        [targetContainer addSubview:label];

        self.cowbellLabel = label;

        /*
         ============================================================
         Cowbell 百分比位置
         ============================================================

         原来：
             bottomAnchor -> 整个 contentView 底部

         这样二级菜单展开以后，百分比会跑到整个大卡片的
         最下面。

         现在：
             centerX -> contentView 中心
             top     -> contentView 的垂直中心 + 8pt

         效果：
             ┌─────────────┐
             │             │
             │   🔋        │
             │   82%       │
             │             │
             └─────────────┘

         不再锁死整个卡片的底部。
         ============================================================
         */

        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor
                constraintEqualToAnchor:targetContainer.centerXAnchor],

            [label.topAnchor
                constraintEqualToAnchor:targetContainer.centerYAnchor
                constant:8.0]
        ]];
    }

    [self updateCowbellState];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {

        NSNotificationCenter *nc =
            [NSNotificationCenter defaultCenter];

        [nc removeObserver:self
                      name:NSProcessInfoPowerStateDidChangeNotification
                    object:nil];

        [nc removeObserver:self
                      name:UIDeviceBatteryLevelDidChangeNotification
                    object:nil];

        [nc addObserver:self
               selector:@selector(updateCowbellState)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];

        [nc addObserver:self
               selector:@selector(updateCowbellState)
                   name:UIDeviceBatteryLevelDidChangeNotification
                 object:nil];

        [self updateCowbellState];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {

        NSNotificationCenter *nc =
            [NSNotificationCenter defaultCenter];

        [nc removeObserver:self
                      name:NSProcessInfoPowerStateDidChangeNotification
                    object:nil];

        [nc removeObserver:self
                      name:UIDeviceBatteryLevelDidChangeNotification
                    object:nil];
    }
}

// 展开大卡片时淡出隐藏，切回时淡入
- (void)willTransitionToExpandedContentMode:(BOOL)expanded {
    %orig(expanded);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {

        if (!self.cowbellLabel) return;

        [UIView animateWithDuration:0.25 animations:^{
            self.cowbellLabel.alpha = expanded ? 0.0 : 1.0;
        }];
    }
}

%end

#pragma clang diagnostic pop