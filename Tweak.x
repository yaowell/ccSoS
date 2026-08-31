#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

extern NSString *const kCAFilterDestOut;

static const NSInteger kPercentTag = 0xBB22;


/*
 * ============================================================
 * CCUIToggleViewController
 *
 * 必须完整声明。
 * 否则 Theos/Clang 只知道 @class，
 * self.view / [self class] 都会报错。
 * ============================================================
 */

@interface CCUIToggleViewController : UIViewController

@end


/*
 * ============================================================
 * CCUIToggleViewController
 * ============================================================
 */

%hook CCUIToggleViewController


- (void)viewWillAppear:(BOOL)animated {

    %orig(animated);


    /*
     * ========================================================
     * 读取 _module
     * ========================================================
     */

    Ivar modIvar =
        class_getInstanceVariable(
            [CCUIToggleViewController class],
            "_module"
        );


    if (!modIvar) {

        NSLog(
            @"[SimpleCowbell] _module NOT FOUND"
        );

        return;
    }


    /*
     * ========================================================
     * 从当前 VC 实例读取 _module
     * ========================================================
     */

    id module =
        object_getIvar(
            self,
            modIvar
        );


    if (!module) {

        NSLog(
            @"[SimpleCowbell] _module = nil"
        );

        return;
    }


    NSString *moduleClass =
        NSStringFromClass(
            [module class]
        );


    NSLog(
        @"[SimpleCowbell] module = %@",
        moduleClass
    );


    /*
     * ========================================================
     * 只处理低电量模块
     * ========================================================
     */

    if (![moduleClass
            isEqualToString:@"CCUILowPowerModule"]) {

        return;
    }


    NSLog(
        @"[SimpleCowbell] CCUILowPowerModule FOUND"
    );


    /*
     * ========================================================
     * 获取真正的 VC View
     * ========================================================
     */

    UIView *view =
        self.view;


    if (!view) {

        NSLog(
            @"[SimpleCowbell] self.view = nil"
        );

        return;
    }


    NSLog(
        @"[SimpleCowbell] view=%@",
        view
    );


    NSLog(
        @"[SimpleCowbell] bounds=%@",
        NSStringFromCGRect(
            view.bounds
        )
    );


    NSLog(
        @"[SimpleCowbell] window=%@",
        view.window
    );


    /*
     * ========================================================
     * 查找已有 Label
     * ========================================================
     */

    UILabel *label =
        [view viewWithTag:kPercentTag];


    /*
     * ========================================================
     * 创建 Label
     * ========================================================
     */

    if (!label) {

        label =
            [[UILabel alloc] init];


        label.tag =
            kPercentTag;


        label.textAlignment =
            NSTextAlignmentCenter;


        label.font =
            [UIFont systemFontOfSize:
                10.0f
                weight:UIFontWeightSemibold];


        /*
         * ====================================================
         * Cowbell 镂空效果
         * ====================================================
         */

        label.layer.allowsGroupOpacity =
            YES;


        /*
         * allowsGroupBlending 是私有属性，
         * 不能直接写：
         *
         * label.layer.allowsGroupBlending
         *
         * 所以这里不再使用。
         */


        label.layer.compositingFilter =
            kCAFilterDestOut;


        [view addSubview:label];


        NSLog(
            @"[SimpleCowbell] Label CREATED"
        );
    }


    /*
     * ========================================================
     * 读取当前真实电量
     * ========================================================
     */

    UIDevice *device =
        [UIDevice currentDevice];


    device.batteryMonitoringEnabled =
        YES;


    float level =
        device.batteryLevel;


    NSLog(
        @"[SimpleCowbell] batteryLevel = %f",
        level
    );


    /*
     * 如果系统返回 -1，
     * 说明当前无法读取电量。
     */

    if (level < 0.0f) {

        NSLog(
            @"[SimpleCowbell] batteryLevel INVALID"
        );

        return;
    }


    /*
     * ========================================================
     * 转换百分比
     * ========================================================
     */

    int percent =
        (int)round(
            level * 100.0f
        );


    label.text =
        [NSString stringWithFormat:
            @"%d%%",
            percent
        ];


    /*
     * ========================================================
     * 定位
     * ========================================================
     */

    [label sizeToFit];


    CGRect bounds =
        view.bounds;


    label.frame =
        CGRectMake(
            CGRectGetMidX(bounds)
                - label.bounds.size.width
                / 2.0f,

            bounds.size.height
                * 0.70f,

            label.bounds.size.width,

            label.bounds.size.height
        );


    NSLog(
        @"[SimpleCowbell] Label frame=%@",
        NSStringFromCGRect(
            label.frame
        )
    );


    NSLog(
        @"[SimpleCowbell] Label text=%@",
        label.text
    );
}


%end