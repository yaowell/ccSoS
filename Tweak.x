#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@property (nonatomic, retain) UILabel *cowbellLabel;
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

    // 读取电量并更新文字
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
}

- (void)viewDidLoad {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        if (!self.cowbellLabel) {
            UILabel *label = [[UILabel alloc] init];
            label.translatesAutoresizingMaskIntoConstraints = NO; // 开启 Auto Layout
            label.textColor = [UIColor whiteColor];
            label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
            label.textAlignment = NSTextAlignmentCenter;
            label.userInteractionEnabled = NO;

            [self.view addSubview:label];
            self.cowbellLabel = label;

            // 使用 Auto Layout 锚定：水平居中，垂直固定在模块下半部分
            [NSLayoutConstraint activateConstraints:@[
                [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
                [label.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10]
            ]];
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

// 完美解决二级菜单展开时下方透出百分比的问题
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

#pragma clang diagnostic pop
