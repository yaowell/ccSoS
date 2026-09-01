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

// 读取系统 UI 呈现电量（解决与右上角状态栏百分比不一致的问题）
static int CowbellGetRealBatteryPercent(void) {
#ifndef kIOMainPortDefault
    #define kIOMainPortDefault kIOMasterPortDefault
#endif

    mach_port_t mainPort = kIOMainPortDefault;
    io_service_t service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSmartBattery"));
    if (!service) return 0;

    // 优先读取系统校准后的 UIBatteryPercent
    CFNumberRef percentObj = IORegistryEntryCreateCFProperty(service, CFSTR("UIBatteryPercent"), kCFAllocatorDefault, 0);
    
    // 降级处理：若无该属性则读取物理容量比值
    if (!percentObj) {
        CFNumberRef currentCap = IORegistryEntryCreateCFProperty(service, CFSTR("AppleRawCurrentCapacity"), kCFAllocatorDefault, 0);
        CFNumberRef maxCap = IORegistryEntryCreateCFProperty(service, CFSTR("AppleRawMaxCapacity"), kCFAllocatorDefault, 0);
        IOObjectRelease(service);

        if (!currentCap || !maxCap) {
            if (currentCap) CFRelease(currentCap);
            if (maxCap) CFRelease(maxCap);
            return 0;
        }

        NSInteger cur = 0, max = 0;
        CFNumberGetValue(currentCap, kCFNumberNSIntegerType, &cur);
        CFNumberGetValue(maxCap, kCFNumberNSIntegerType, &max);
        CFRelease(currentCap);
        CFRelease(maxCap);

        if (max <= 0) return 0;
        int pct = (int)round(((double)cur / (double)max) * 100.0);
        return (pct < 0) ? 0 : ((pct > 100) ? 100 : pct);
    }

    IOObjectRelease(service);
    NSInteger percent = 0;
    CFNumberGetValue(percentObj, kCFNumberNSIntegerType, &percent);
    CFRelease(percentObj);

    return (int)percent;
}

static UILabel *CowbellGetLabel(CCUICAPackageView *view) {
    return objc_getAssociatedObject(view, &kCowbellPercentLabelKey);
}

// 快速识别与强行缓存
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

// 刷新处理函数（仿照 updateBatteryText 逻辑）
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

    // 移除旧的 block 监听，采用显式的 target-action 方式向 NotificationCenter 注册
    // 保证在 View 存活期间，广播能精准调用 CowbellUpdatePercent
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:view]; // 先移除旧监听防止重复绑定
    
    [nc addObserver:view
           selector:@selector(cowbell_updateBatteryNotification:)
               name:UIDeviceBatteryLevelDidChangeNotification
             object:nil];
             
    [nc addObserver:view
           selector:@selector(cowbell_updateBatteryNotification:)
               name:NSProcessInfoPowerStateDidChangeNotification
             object:nil];

    return label;
}

%hook CCUICAPackageView

// 为 CCUICAPackageView 动态扩展响应通知的方法
%new
- (void)cowbell_updateBatteryNotification:(NSNotification *)note {
    CowbellUpdatePercent(self);
}

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

    // 每次布局更新时强行刷新（等价于 viewWillAppear 里的刷新）
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
    } else {
        // 视图移出屏幕时清理通知监听（等价于 dealloc/viewDidDisappear 里的移除）
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

%end

#pragma clang diagnostic pop
