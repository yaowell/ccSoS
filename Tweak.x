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

// 极其高效的 IOKit 电量获取（不开启系统电池监控机制）
static int CowbellGetRealBatteryPercent(void) {
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

// 快速判定与缓存机制（非目标 View 瞬间拦截）
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

    // 无论 YES 还是 NO 都强行缓存，保证非低电量图标下次 1 毫秒内退出
    objc_setAssociatedObject(view, &kCowbellIsLowPowerKey, @(matched), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return matched;
}

// 刷新百分比与颜色（纯 CPU 计算，零 dispatch 排队）
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

    // 系统广播注册
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

    // 非低电量图标第 1 行直接退出，极低消耗
    if (!CowbellIsLowPowerPackage(self)) return;

    UILabel *label = CowbellCreateLabel(self);
    if (!label) return;

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    if (width <= 0 || height <= 0) return;

    CGFloat centerY = height * 0.5f;
    CGFloat y = centerY + COWBELL_PERCENT_Y_OFFSET;

    label.frame = CGRectMake(0, y, width, 11.0f);
    [self bringSubviewToFront:label];
    
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
