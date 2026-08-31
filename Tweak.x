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

            CAFilter *filter = [CAFilter filterWithType:kCAFilterDestOut];
            label.layer.filters = @[filter];

            [targetContainer addSubview:label];
            self.cowbellLabel = label;
        }

        if (self.cowbellLabel) {
            BOOL isExpandedState = NO;
            if ([self respondsToSelector:@selector(isExpanded)]) {
                isExpandedState = self.expanded;
            }

            CGFloat containerW = targetContainer.bounds.size.width;
            CGFloat containerH = targetContainer.bounds.size.height;

            [self.cowbellLabel sizeToFit];
            CGFloat labelW = self.cowbellLabel.frame.size.width;
            CGFloat labelH = self.cowbellLabel.frame.size.height;

            if (isExpandedState || containerH > 200.0) {
                // 二级展开状态：把文字强行放在顶部大电池正下方（Y轴设为 82）
                self.cowbellLabel.translatesAutoresizingMaskIntoConstraints = YES;
                self.cowbellLabel.frame = CGRectMake(
                    (containerW - labelW) / 2.0,
                    82.0, // 此处即为大电池下方的位置
                    labelW,
                    labelH
                );
            } else {
                // 一级小卡片状态：强行放置在底部
                self.cowbellLabel.translatesAutoresizingMaskIntoConstraints = YES;
                self.cowbellLabel.frame = CGRectMake(
                    (containerW - labelW) / 2.0,
                    containerH - labelH - 6.0,
                    labelW,
                    labelH
                );
            }
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

%end

#pragma clang diagnostic pop
