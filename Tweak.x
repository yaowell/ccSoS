#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <IOKit/IOKitLib.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@end


static char kCowbellPercentLabelKey;
static char kCowbellIsLowPowerKey;


/*
 ============================================================
                    百分比位置
 ============================================================
 */

static CGFloat const COWBELL_PERCENT_Y_OFFSET = 12.0;


/*
 ============================================================
                    IOKit 获取真实电量
 ============================================================
 */

static int CowbellGetRealBatteryPercent(void) {

#ifndef kIOMainPortDefault
#define kIOMainPortDefault kIOMasterPortDefault
#endif

    mach_port_t mainPort = kIOMainPortDefault;

    io_service_t service =
        IOServiceGetMatchingService(
            mainPort,
            IOServiceMatching("AppleSmartBattery")
        );

    if (!service) {
        return 0;
    }

    CFNumberRef currentCapObj =
        IORegistryEntryCreateCFProperty(
            service,
            CFSTR("AppleRawCurrentCapacity"),
            kCFAllocatorDefault,
            0
        );

    CFNumberRef maxCapObj =
        IORegistryEntryCreateCFProperty(
            service,
            CFSTR("AppleRawMaxCapacity"),
            kCFAllocatorDefault,
            0
        );

    IOObjectRelease(service);

    if (!currentCapObj || !maxCapObj) {

        if (currentCapObj) {
            CFRelease(currentCapObj);
        }

        if (maxCapObj) {
            CFRelease(maxCapObj);
        }

        return 0;
    }

    NSInteger current = 0;
    NSInteger max = 0;

    CFNumberGetValue(
        currentCapObj,
        kCFNumberNSIntegerType,
        &current
    );

    CFNumberGetValue(
        maxCapObj,
        kCFNumberNSIntegerType,
        &max
    );

    CFRelease(currentCapObj);
    CFRelease(maxCapObj);

    if (max <= 0) {
        return 0;
    }

    int percent =
        (int)round(
            ((double)current / (double)max) * 100.0
        );

    if (percent < 0) {
        percent = 0;
    }

    if (percent > 100) {
        percent = 100;
    }

    return percent;
}


/*
 ============================================================
                  获取百分比 Label
 ============================================================
 */

static UILabel *CowbellGetLabel(CCUICAPackageView *view) {

    return objc_getAssociatedObject(
        view,
        &kCowbellPercentLabelKey
    );
}


/*
 ============================================================
                  判断低电量 Package
 ============================================================
 */

static BOOL CowbellIsLowPowerPackage(
    CCUICAPackageView *view
) {

    NSNumber *cached =
        objc_getAssociatedObject(
            view,
            &kCowbellIsLowPowerKey
        );

    if (cached) {
        return cached.boolValue;
    }

    BOOL matched = NO;

    NSString *pkgName = @"";

    if ([view respondsToSelector:@selector(packageName)]) {

        pkgName =
            view.packageName ?: @"";
    }

    if ([pkgName containsString:@"LowPower"] ||
        [pkgName containsString:@"Battery"]) {

        matched = YES;

    } else {

        for (
            UIResponder *r = view;
            r;
            r = [r nextResponder]
        ) {

            NSString *cls =
                NSStringFromClass([r class]);

            if ([cls containsString:@"Brightness"] ||
                [cls containsString:@"Display"]) {

                break;
            }

            if ([cls containsString:@"LowPower"]) {

                matched = YES;
                break;
            }
        }
    }

    objc_setAssociatedObject(
        view,
        &kCowbellIsLowPowerKey,
        @(matched),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    return matched;
}


/*
 ============================================================
                    刷新百分比
 ============================================================
 */

static void CowbellUpdatePercent(
    CCUICAPackageView *view
) {

    if (!view) {
        return;
    }

    UILabel *label =
        CowbellGetLabel(view);

    if (!label) {
        return;
    }

    if (!label.window) {
        return;
    }

    /*
     --------------------------------------------------------
                  确保系统电量监听已经开启
     --------------------------------------------------------
     */

    if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {

        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    }


    /*
     --------------------------------------------------------
                       获取真实电量
     --------------------------------------------------------
     */

    int percent =
        CowbellGetRealBatteryPercent();

    label.text =
        [NSString stringWithFormat:@"%d%%", percent];


    /*
     --------------------------------------------------------
                    一级 / 二级颜色规则
     --------------------------------------------------------

     一级：
        普通 = 白色
        低电量 = 黑色

     二级：
        永远 = 白色

     这里通过父控制器状态判断。
     --------------------------------------------------------
     */

    BOOL isExpanded = NO;

    UIResponder *responder = view;

    while (responder) {

        if (
            [responder
             isKindOfClass:
             [CCUIContentModuleContainerViewController class]]
        ) {

            /*
             这里不直接访问不存在的属性，
             只通过 UIViewController 的视图层级状态判断。
             */

            UIViewController *controller =
                (UIViewController *)responder;

            /*
             ------------------------------------------------
             二级菜单通常会产生更大的 view 高度。
             这里不改变位置，只用于颜色判断。
             ------------------------------------------------
             */

            UIView *controllerView =
                controller.view;

            if (controllerView) {

                /*
                 如果控制器 view 高度明显大于一级模块，
                 认为当前处于展开状态。
                 */

                CGFloat h =
                    controllerView.bounds.size.height;

                if (h > 150.0) {
                    isExpanded = YES;
                }
            }

            break;
        }

        responder =
            [responder nextResponder];
    }


    /*
     --------------------------------------------------------
                      最终颜色
     --------------------------------------------------------
     */

    if (isExpanded) {

        // 二级菜单永远白色
        label.textColor =
            [UIColor whiteColor];

    } else {

        // 一级菜单根据低电量模式改变
        BOOL lowPower =
            [NSProcessInfo processInfo]
            .isLowPowerModeEnabled;

        label.textColor =
            lowPower
            ? [UIColor blackColor]
            : [UIColor whiteColor];
    }


    /*
     ========================================================
                         镂空效果
     ========================================================
     */

    CAFilter *filter =
        [CAFilter filterWithType:kCAFilterDestOut];

    label.layer.filters =
        @[filter];
}


/*
 ============================================================
                    创建百分比 Label
 ============================================================
 */

static UILabel *CowbellCreateLabel(
    CCUICAPackageView *view
) {

    UILabel *label =
        CowbellGetLabel(view);

    if (label) {
        return label;
    }


    label =
        [[UILabel alloc] init];


    label.textAlignment =
        NSTextAlignmentCenter;

    label.userInteractionEnabled =
        NO;

    label.backgroundColor =
        [UIColor clearColor];

    label.textColor =
        [UIColor whiteColor];

    label.font =
        [UIFont systemFontOfSize:9.5
                          weight:UIFontWeightRegular];

    label.tag = 9998;


    /*
     --------------------------------------------------------
                       镂空
     --------------------------------------------------------
     */

    CAFilter *filter =
        [CAFilter filterWithType:kCAFilterDestOut];

    label.layer.filters =
        @[filter];


    [view addSubview:label];


    objc_setAssociatedObject(
        view,
        &kCowbellPercentLabelKey,
        label,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );


    /*
     ========================================================
                   关键：开启电量监听
     ========================================================
     */

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;


    /*
     ========================================================
                    电量变化监听
     ========================================================
     */

    NSNotificationCenter *nc =
        [NSNotificationCenter defaultCenter];


    [nc addObserverForName:
            UIDeviceBatteryLevelDidChangeNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {

        CowbellUpdatePercent(view);
    }];


    /*
     ========================================================
                  充电状态变化监听
     ========================================================
     */

    [nc addObserverForName:
            UIDeviceBatteryStateDidChangeNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {

        CowbellUpdatePercent(view);
    }];


    /*
     ========================================================
                    低电量模式监听
     ========================================================
     */

    [nc addObserverForName:
            NSProcessInfoPowerStateDidChangeNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {

        CowbellUpdatePercent(view);
    }];


    return label;
}


/*
 ============================================================
                  CCUICAPackageView
 ============================================================
 */

%hook CCUICAPackageView


- (void)layoutSubviews {

    %orig;


    /*
     --------------------------------------------------------
                  非目标模块直接退出
     --------------------------------------------------------
     */

    if (!CowbellIsLowPowerPackage(self)) {
        return;
    }


    /*
     --------------------------------------------------------
                    确保电量监听开启
     --------------------------------------------------------
     */

    if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {

        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    }


    UILabel *label =
        CowbellCreateLabel(self);

    if (!label) {
        return;
    }


    CGFloat width =
        self.bounds.size.width;

    CGFloat height =
        self.bounds.size.height;


    if (width <= 0 ||
        height <= 0) {

        return;
    }


    /*
     ========================================================
                     百分比位置
     ========================================================
     */

    CGFloat centerY =
        height * 0.5f;

    CGFloat y =
        centerY +
        COWBELL_PERCENT_Y_OFFSET;


    label.frame =
        CGRectMake(
            0,
            y,
            width,
            11.0f
        );


    /*
     ========================================================
                    保证百分比最上层
     ========================================================
     */

    [self bringSubviewToFront:label];


    /*
     ========================================================
                       刷新
     ========================================================
     */

    CowbellUpdatePercent(self);
}


/*
 ============================================================
                     进入窗口
 ============================================================
 */

- (void)didMoveToWindow {

    %orig;


    if (!CowbellIsLowPowerPackage(self)) {
        return;
    }


    if (self.window) {

        /*
         ----------------------------------------------------
                     再次确保监听开启
         ----------------------------------------------------
         */

        [UIDevice currentDevice]
            .batteryMonitoringEnabled = YES;


        UILabel *label =
            CowbellGetLabel(self);


        if (label) {

            label.hidden = NO;
            label.alpha = 1.0f;

            CowbellUpdatePercent(self);
        }
    }
}


%end


#pragma clang diagnostic pop