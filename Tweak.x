#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// 声明系统底层按钮类
@interface CCUIRoundButton : UIView
@property (nonatomic, retain) UILabel *cowbellLabel;
- (void)updateCowbellState;
@end

@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@end

// 1. Hook 底层按钮组件：文字直接绑定在图标内部
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

    // 读取当前系统电量
    float level = [[UIDevice currentDevice] batteryLevel];
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
    [self.cowbellLabel sizeToFit];

    // 布局在按钮内部下方（基于自身 bounds 相对定位）
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    CGFloat btnW = self.bounds.size.width > 0 ? self.bounds.size.width : 52.0;
    CGFloat btnH = self.bounds.size.height > 0 ? self.bounds.size.height : 52.0;
    CGFloat labelW = self.cowbellLabel.frame.size.width;
    CGFloat labelH = self.cowbellLabel.frame.size.height;

    self.cowbellLabel.frame = CGRectMake(
        (btnW - labelW) / 2.0,
        btnH * 0.72 - (labelH / 2.0),
        labelW,
        labelH
    );

    // 根据低电量模式自动切黑/白字
    BOOL isLPMOn = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    self.cowbellLabel.textColor = isLPMOn ? [UIColor blackColor] : [UIColor whiteColor];

    [CATransaction commit];
}

- (void)layoutSubviews {
    %orig;
    // 如果该按钮内部包含 cowbellLabel，随按钮重新布局
    if (self.cowbellLabel) {
        [self updateCowbellState];
    }
}

%end


// 2. Hook 模块控制器：仅负责初始化与通知注册
%hook CCUIContentModuleContainerViewController

- (void)viewDidLoad {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        // 寻找低电量模块内部真正的 CCUIRoundButton
        CCUIRoundButton *roundButton = nil;
        for (UIView *subview in self.view.subviews) {
            if ([subview isKindOfClass:%c(CCUIRoundButton)]) {
                roundButton = (CCUIRoundButton *)subview;
                break;
            } else {
                for (UIView *innerView in subview.subviews) {
                    if ([innerView isKindOfClass:%c(CCUIRoundButton)]) {
                        roundButton = (CCUIRoundButton *)innerView;
                        break;
                    }
                }
            }
        }

        // 将 UILabel 注入到按钮内部
        if (roundButton && !roundButton.cowbellLabel) {
            UILabel *label = [[UILabel alloc] init];
            label.textColor = [UIColor whiteColor];
            label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
            label.textAlignment = NSTextAlignmentCenter;
            label.userInteractionEnabled = NO;

            [roundButton addSubview:label];
            roundButton.cowbellLabel = label;
            [roundButton updateCowbellState];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    if ([self.moduleIdentifier isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [nc removeObserver:self name:UIDeviceBatteryLevelDidChangeNotification object:nil];

        // 监听电量与低电量模式切换
        [nc addObserver:self selector:@selector(cowbell_updateSubviews) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(cowbell_updateSubviews) name:UIDeviceBatteryLevelDidChangeNotification object:nil];

        [self cowbell_updateSubviews];
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

%new
- (void)cowbell_updateSubviews {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cowbell_updateSubviews];
        });
        return;
    }

    for (UIView *subview in self.view.subviews) {
        if ([subview isKindOfClass:%c(CCUIRoundButton)]) {
            [(CCUIRoundButton *)subview updateCowbellState];
        } else {
            for (UIView *innerView in subview.subviews) {
                if ([innerView isKindOfClass:%c(CCUIRoundButton)]) {
                    [(CCUIRoundButton *)innerView updateCowbellState];
                }
            }
        }
    }
}

%end

#pragma clang diagnostic pop
