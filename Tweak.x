#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString *const kCAFilterDestOut;


/*
 ============================================================
                    CAFilter
 ============================================================
 */

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end


/*
 ============================================================
                  CCUICAPackageView
 ============================================================
 */

@interface CCUICAPackageView : UIView

@property (nonatomic, copy) NSString *packageName;

@end


/*
 ============================================================
        Cowbell Percent Label Associated Object
 ============================================================
 */

static char kCowbellPercentLabelKey;
static char kCowbellIsLowPowerKey;


/*
 ============================================================
                    位置参数
 ============================================================

 一级菜单百分比位置：

 数字越大  -> 越往下
 数字越小  -> 越往上

 这个参数只负责百分比位置。

 不负责电池图标。
 不负责二级菜单。
 ============================================================
 */

static CGFloat const COWBELL_PERCENT_Y_OFFSET = 10.0;


/*
 ============================================================
                  获取 Cowbell Label
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
                判断是否为低电量模块
 ============================================================
 */

static BOOL CowbellIsLowPowerPackage(CCUICAPackageView *view) {

    NSNumber *cached =
        objc_getAssociatedObject(
            view,
            &kCowbellIsLowPowerKey
        );

    if (cached) {
        return cached.boolValue;
    }


    BOOL matched = NO;


    /*
     --------------------------------------------------------
                    packageName 判断
     --------------------------------------------------------
     */

    NSString *pkgName = @"";

    if ([view respondsToSelector:@selector(packageName)]) {
        pkgName = view.packageName ?: @"";
    }


    if ([pkgName containsString:@"LowPower"] ||
        [pkgName containsString:@"Battery"]) {

        matched = YES;
    }


    /*
     --------------------------------------------------------
                    responder 判断
     --------------------------------------------------------
     */

    if (!matched) {

        for (UIResponder *r = view;
             r;
             r = [r nextResponder]) {

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

static void CowbellUpdatePercent(CCUICAPackageView *view) {

    if (!view) return;


    UILabel *label =
        CowbellGetLabel(view);


    if (!label) return;


    if (!label.window) return;


    dispatch_async(dispatch_get_main_queue(), ^{

        if (!label.window) return;


        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {

            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }


        float level =
            UIDevice.currentDevice.batteryLevel;


        if (level < 0) {
            level = 1.0f;
        }


        int percent =
            (int)round(level * 100.0f);


        label.text =
            [NSString stringWithFormat:@"%d%%", percent];


        /*
         ----------------------------------------------------
                       低电量模式颜色
         ----------------------------------------------------
         */

        BOOL lowPower =
            [NSProcessInfo processInfo].isLowPowerModeEnabled;


        label.textColor =
            lowPower
            ? [UIColor blackColor]
            : [UIColor whiteColor];


        /*
         ----------------------------------------------------
                         镂空
         ----------------------------------------------------
         */

        CAFilter *filter =
            [CAFilter filterWithType:kCAFilterDestOut];


        label.layer.filters =
            @[filter];


        [label setNeedsLayout];
    });
}


/*
 ============================================================
                     创建百分比
 ============================================================
 */

static UILabel *CowbellCreateLabel(CCUICAPackageView *view) {

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
        [UIFont systemFontOfSize:9.3
                          weight:UIFontWeightRegular];


    /*
     ========================================================
                       Cowbell 镂空
     ========================================================
     */

    CAFilter *filter =
        [CAFilter filterWithType:kCAFilterDestOut];


    label.layer.filters =
        @[filter];


    label.tag = 9998;


    /*
     ========================================================
                  让 Label 跟随 Package View
     ========================================================
     */

    [view addSubview:label];


    objc_setAssociatedObject(
        view,
        &kCowbellPercentLabelKey,
        label,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );


    /*
     ========================================================
                       电量监听
     ========================================================
     */

    [[NSNotificationCenter defaultCenter]
        addObserverForName:
            UIDeviceBatteryLevelDidChangeNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *note) {

            CowbellUpdatePercent(view);
        }];


    [[NSNotificationCenter defaultCenter]
        addObserverForName:
            UIDeviceBatteryStateDidChangeNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *note) {

            CowbellUpdatePercent(view);
        }];


    [[NSNotificationCenter defaultCenter]
        addObserverForName:
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
              递归寻找 PackageView
              
              注意：
              不使用递归 Block。
              避免 Theos -Werror 编译错误。
 ============================================================
 */

static void CowbellFindPackageViews(
    UIView *root,
    NSMutableArray *packageViews
) {

    if (!root) return;


    Class packageClass =
        NSClassFromString(@"CCUICAPackageView");


    if (packageClass &&
        [root isKindOfClass:packageClass]) {

        [packageViews addObject:root];
    }


    for (UIView *subview in root.subviews) {

        CowbellFindPackageViews(
            subview,
            packageViews
        );
    }
}


/*
 ============================================================
                    CCUICAPackageView Hook
 ============================================================
 */

%hook CCUICAPackageView


- (void)layoutSubviews {

    %orig;


    /*
     ========================================================
                   不是低电量模块
     ========================================================
     */

    if (!CowbellIsLowPowerPackage(self)) {
        return;
    }


    /*
     ========================================================
                     电量监控
     ========================================================
     */

    if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {

        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    }


    /*
     ========================================================
                     获取百分比
     ========================================================
     */

    UILabel *label =
        CowbellCreateLabel(self);


    if (!label) return;


    /*
     ========================================================
                     防止干扰原生图标
     ========================================================

     这里不隐藏原生 subview。

     原生电池图标完全保留。
     ========================================================
     */


    /*
     ========================================================
                     Package View 尺寸
     ========================================================
     */

    CGFloat width =
        self.bounds.size.width;


    CGFloat height =
        self.bounds.size.height;


    if (width <= 0 ||
        height <= 0 ||
        width > 200 ||
        height > 200) {

        return;
    }


    /*
     ========================================================
                     百分比位置
     ========================================================

     以 Package View 的中心为基础。

     一级菜单位置只由：

         COWBELL_PERCENT_Y_OFFSET

     控制。
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


    label.font =
        [UIFont systemFontOfSize:10.0
                          weight:UIFontWeightRegular];


    /*
     ========================================================
                    保证百分比在最上层
     ========================================================
     */

    [self bringSubviewToFront:label];


    /*
     ========================================================
                       刷新电量
     ========================================================
     */

    CowbellUpdatePercent(self);
}


- (void)didMoveToWindow {

    %orig;


    if (!CowbellIsLowPowerPackage(self)) {
        return;
    }


    if (self.window) {

        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {

            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }


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


/*
 ============================================================
              Controller 层只负责二级隐藏 / 恢复
 ============================================================

 注意：

 这里不负责位置。

 位置完全由 CCUICAPackageView 管理。

 ============================================================
 */

@interface CCUIContentModuleContainerViewController : UIViewController

@property (nonatomic, readonly, copy) NSString *moduleIdentifier;

@end


%hook CCUIContentModuleContainerViewController


- (void)willTransitionToExpandedContentMode:(BOOL)expanded {

    %orig(expanded);


    /*
     ========================================================
                    只处理低电量模块
     ========================================================
     */

    if (![self.moduleIdentifier
          isEqualToString:
          @"com.apple.control-center.LowPowerModule"]) {

        return;
    }


    /*
     ========================================================
                  找到当前页面里的 PackageView
     ========================================================
     */

    NSMutableArray *packageViews =
        [NSMutableArray array];


    CowbellFindPackageViews(
        self.view,
        packageViews
    );


    /*
     ========================================================
                       执行显示状态
     ========================================================
     */

    for (CCUICAPackageView *packageView
         in packageViews) {

        UILabel *label =
            CowbellGetLabel(packageView);


        if (!label) continue;


        if (expanded) {

            /*
             ------------------------------------------------
                         一级 -> 二级
             ------------------------------------------------

             二级彻底隐藏。
             */

            label.hidden = YES;
            label.alpha = 0.0f;

        } else {

            /*
             ------------------------------------------------
                         二级 -> 一级
             ------------------------------------------------

             先显示对象，
             再由系统 PackageView 布局。

             避免百分比晚于图标。
             */

            label.hidden = NO;
            label.alpha = 1.0f;

            CowbellUpdatePercent(packageView);
        }
    }
}


%end


#pragma clang diagnostic pop