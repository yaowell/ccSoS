#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    typedef void *io_object_t;
    typedef io_object_t io_service_t;
    typedef uint32_t mach_port_t;
    
    io_service_t IOServiceGetMatchingService(mach_port_t mainPort, CFDictionaryRef matching);
    CFMutableDictionaryRef IOServiceMatching(const char *name);
    CFTypeRef IORegistryEntryCreateCFProperty(io_service_t entry, CFStringRef key, CFAllocatorRef allocator, uint32_t options);
    kern_return_t IOObjectRelease(io_object_t object);
#ifdef __cplusplus
}
#endif

// 獲取精確電量
static int getPreciseBatteryPercent(void) {
    io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"));
    if (!service) return 0;

    CFNumberRef currentCapObj = (CFNumberRef)IORegistryEntryCreateCFProperty(service, CFSTR("AppleRawCurrentCapacity"), kCFAllocatorDefault, 0);
    CFNumberRef maxCapObj = (CFNumberRef)IORegistryEntryCreateCFProperty(service, CFSTR("AppleRawMaxCapacity"), kCFAllocatorDefault, 0);

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

@interface CCUILowPowerModuleViewController : UIViewController
- (void)updateCowbellLabel;
@end

%hook CCUILowPowerModuleViewController

- (void)viewDidLoad {
    %orig;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellLabel)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellLabel)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self updateCowbellLabel];
}

- (void)viewWillLayoutSubviews {
    %orig;
    [self updateCowbellLabel];
}

%new
- (void)updateCowbellLabel {
    UIView *targetContainer = self.view;
    if (!targetContainer) return;

    int percent = getPreciseBatteryPercent();
    if (percent == 0) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        float level = [UIDevice currentDevice].batteryLevel;
        if (level >= 0) percent = (int)round(level * 100.0);
    }

    UILabel *label = (UILabel *)[targetContainer viewWithTag:88888];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 88888;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [targetContainer addSubview:label];

        // 強制居中在按鈕圖示下方
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:targetContainer.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:targetContainer.bottomAnchor constant:-6]
        ]];
    }

    label.text = [NSString stringWithFormat:@"%d%%", percent];

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    if (isLowPower) {
        label.textColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    } else {
        label.textColor = [UIColor whiteColor];
    }

    [targetContainer bringSubviewToFront:label];
}

%end
