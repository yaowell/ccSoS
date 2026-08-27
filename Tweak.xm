#import <UIKit/UIKit.h>

// 显式声明 IOKit 底层 C 函数与常量，避免头文件 module 冲突
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

// 获取真实电池百分比
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

- (void)viewDidLayoutSubviews {
    %orig;
    [self updateCowbellLabel];
}

%new
- (void)updateCowbellLabel {
    int percent = getPreciseBatteryPercent();
    UIView *parentView = self.view;
    if (!parentView) return;

    UILabel *label = (UILabel *)[parentView viewWithTag:88888];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 88888;
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [parentView addSubview:label];

        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:parentView.bottomAnchor constant:-4]
        ]];
    }

    label.text = [NSString stringWithFormat:@"%d%%", percent];

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    if (isLowPower) {
        label.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.9];
    } else {
        label.textColor = [UIColor whiteColor];
    }

    [parentView bringSubviewToFront:label];
}

%end
