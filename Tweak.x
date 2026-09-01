#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <IOKit/IOKitLib.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

static char kCowbellPercentLabelKey;
static char kCowbellIsLowPowerKey;

static CGFloat const COWBELL_PERCENT_Y_OFFSET = 12.0;

// 底层 IOKit 读取电量，不开启系统轮询
static int CowbellGetRealBatteryPercent(void) {
#ifndef kIOMainPortDefault
    #define kIOMainPortDefault kIOMasterPortDefault
#endif

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

static UILabel *CowbellGetLabel(CCUICAPackageView *view) {
    return objc_getAssociatedObject(view, &kCowbellPercentLabelKey);
}

// 精准识别并强行缓存（非低电量图标 1 毫秒弹退）
static BOOL CowbellIsLowPowerPackage(CCUICAPackageView *view) {
    NSNumber *cached = objc_getAssociatedObject(view, &kCowbellIsLowPowerKey);
    if (cached) return cached.boolValue;

    BOOL matched = NO;
    NSString *pkgName = [view respondsToSelector:@selector(packageName)] ? (view.packageName ?: @"") : @"";

    if ([pkgName containsString:@"LowPower"] || [pkgName containsString:@"Battery"]) {
        matched = YES;
    } else {
        for (UIResponder *r = view; r; r = [r nextResponder]) {
            NSString *cls = NSStringFromClass([r class]);
            if ([cls containsString:@"Brightness"] || [cls containsString:@"Display"]) break;
            if ([cls containsString:@"LowPower"]) {
                matched = YES;
                break;
            }
        }
    }

    objc_setAssociatedObject(view, &kCowbellIsLowPowerKey, @(matched), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return matched;
}

// 纯 CPU 同步刷新，无 GCD 异步排队开销
static void CowbellUpdatePercent(CCUICAPackageView *view) {
    if (!view) return;
    UILabel *label = CowbellGetLabel(view);
    if (!label || !label.window) return;

    int percent = CowbellGetRealBatteryPercent();
    label.text = [NSString stringWithFormat:@"%d%%", percent];

    BOOL lowPower = [NSProcessInfo processInfo].isLowPowerModeEnabled;
    label.textColor = lowPower ? [UIColor blackColor] : [UIColor whiteColor];
}

static UILabel *CowbellCreateLabel(CCUICAPackageView *view) {
    UILabel *label = CowbellGetLabel(view);
    if (label) return label;

    label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];
    label.tag = 9998;

    [view addSubview:label];

    objc_setAssociatedObject(view, &kCowbellPercentLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 保留 2 个广播监听，确保后台电量变化/模式切换时实时同步
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        CowbellUpdatePercent(view);
    }];
    [nc addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        CowbellUpdatePercent(view);
    }];

    return label;
}

%hook CCUICAPackageView

- (void)layoutSubviews {
    %orig;

    if (!CowbellIsLowPowerPackage(self)) return;

    UILabel *label = CowbellCreateLabel(self);
    if (!label) return;

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0) return;

    CGFloat centerY = height * 0.5f;
    CGFloat y = centerY + COWBELL_PERCENT_Y_OFFSET;

    label.frame = CGRectMake(0, y, width, 11.0f);
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];

    [self bringSubviewToFront:label];

    // 关键刷新逻辑完全保留：控制中心下拉必刷新最新数值
    CowbellUpdatePercent(self);
}

- (void)didMoveToWindow {
    %orig;

    if (!CowbellIsLowPowerPackage(self)) return;

    if (self.window) {
        UILabel *label = CowbellGetLabel(self);
        if (label) {
            label.hidden = NO;
            label.alpha = 1.0f;
            CowbellUpdatePercent(self);
        }
    }
}

%end

#pragma clang diagnostic pop
