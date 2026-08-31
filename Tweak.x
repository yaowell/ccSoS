#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

extern NSString *const kCAFilterDestOut;

static const NSInteger kPercentTag = 0xBB22;


/*
 * ============================================================
 * CCUIToggleViewController
 * ============================================================
 */

@interface CCUIToggleViewController : UIViewController
@end


%hook CCUIToggleViewController

- (void)viewWillAppear:(BOOL)animated {

    %orig(animated);


    /*
     * ========================================================
     * 通过 Runtime 获取 Class
     *
     * 不要使用：
     *
     * [CCUIToggleViewController class]
     *
     * 否则会产生 linker undefined symbol。
     * ========================================================
     */

    Class toggleClass =
        NSClassFromString(
            @"CCUIToggleViewController"
        );


    if (!toggleClass) {

        NSLog(
            @"[SimpleCowbell] CCUIToggleViewController NOT FOUND"
        );

        return;
    }


    /*
     * ========================================================
     * 查找 _module
     * ========================================================
     */

    Ivar modIvar =
        class_getInstanceVariable(
            toggleClass,
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
     * 读取当前 VC 的 _module
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
     * 获取 VC 的 View
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
        @"[SimpleCowbell] view = %@",
        view
    );


    NSLog(
        @"[SimpleCowbell] bounds = %@",
        NSStringFromCGRect(
            view.bounds
        )
    );


    NSLog(
        @"[SimpleCowbell] window = %@",
        view.window
    );


    /*
     * ========================================================
     * 查找 Label
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
         * 注意：
         *
         * 不再使用 allowsGroupBlending。
         *
         * 因为 CALayer 公共头文件里没有这个属性，
         * 直接写会导致 Theos 编译失败。
         */


        label.layer.allowsGroupOpacity =
            YES;


        /*
         * Cowbell 的镂空效果
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
     * -1 表示暂时无法获取
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
        @"[SimpleCowbell] Label frame = %@",
        NSStringFromCGRect(
            label.frame
        )
    );


    NSLog(
        @"[SimpleCowbell] Label text = %@",
        label.text
    );
}

%end