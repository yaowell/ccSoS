#import <UIKit/UIKit.h>
#import <IOKit/IOKitLib.h>

// 1. 底层精准电量读取（解决 iOS 16 未解锁/低电量模式下 UIDevice 返回 -1.0 的问题）
static int getPreciseBatteryPercent(void) {
    mach_port_t mainPort = kIOMainPortDefault;
    io_service_t service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSmartBattery"));
    if (!service) return 0;

    CFNumberRef currentCapObj = IORegistryEntryCreateCFProperty(service, CFSTR("AppleRawCurrentCapacity"), kCFAllocatorDefault, 0);
    CFNumberRef maxCapObj = IORegistryEntryCreateCFProperty(service, CFSTR("AppleRawMaxCapacity"), kCFAllocatorDefault, 0);

    IOObjectRelease(service);

    if (!currentCapObj || !maxCapObj) {
        if (currentCapObj) CFRelease(currentCapObj);
        if (maxCapObj) CFRelease(maxCapObj);
        return 0;
    }

    NSInteger current = 0, max = 0;
    CFNumberGetValue(currentCapObj, kCFNumberNSIntegerType, &current);
    CFNumberGetValue(maxCapObj, kCFNumberNSIntegerType, &max);

    CFRelease(currentCapObj);
    CFRelease(maxCapObj);

    if (max <= 0) return 0;
    int percent = (int)round(((double)current / (double)max) * 100.0);
    return (percent < 0) ? 0 : ((percent > 100) ? 100 : percent);
}

@interface CCUIRoundButtonViewController : UIViewController
- (UIView *)buttonView;
@end

@interface CCUILowPowerModuleViewController : CCUIRoundButtonViewController
- (void)updateCowbellLabel;
@end

%hook CCUILowPowerModuleViewController

- (void)viewDidLoad {
    %orig;
    
    // 注册系统广播监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellLabel)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellLabel)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
    // 监听设备解锁/锁屏事件，确保未解锁状态下实时刷新
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellLabel)
                                                 name:UIApplicationProtectedDataDidBecomeAvailable
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self updateCowbellLabel];
}

%new
- (void)updateCowbellLabel {
    int percent = getPreciseBatteryPercent();
    
    // 获取 iOS 16 容器视图
    UIView *container = [self respondsToSelector:@selector(buttonView)] ? [self buttonView] : self.view;
    if (!container) return;

    UILabel *label = (UILabel *)[container viewWithTag:88888];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 88888;
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:label];

        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-5]
        ]];
    }

    // 设置百分比文字
    label.text = [NSString stringWithFormat:@"%d%%", percent];

    // 动态颜色控制：开启低电量模式时自动匹配电池边框的深灰色，未开启时显示白色
    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    if (isLowPower) {
        label.textColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:0.9];
    } else {
        label.textColor = [UIColor whiteColor];
    }

    [container bringSubviewToFront:label];
}

%end
