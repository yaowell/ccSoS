#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern NSString *const kCAFilterDestOut;

static const NSInteger kPercentTag = 0xBB22;


%hook CCUIToggleViewController

- (void)viewWillAppear:(BOOL)animated {

    %orig(animated);


    /*
     * ========================================================
     * 读取 CCUIToggleViewController 的 _module
     * ========================================================
     */

    Ivar modIvar =
        class_getInstanceVariable(
            [self class],
            "_module"
        );


    if (!modIvar) {

        NSLog(
            @"[CowbellTest] _module NOT FOUND"
        );

        return;
    }


    id module =
        object_getIvar(
            self,
            modIvar
        );


    if (!module) {

        NSLog(
            @"[CowbellTest] _module = nil"
        );

        return;
    }


    NSString *moduleClass =
        NSStringFromClass(
            [module class]
        );


    NSLog(
        @"[CowbellTest] module = %@",
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
        @"[CowbellTest] CCUILowPowerModule FOUND"
    );


    /*
     * ========================================================
     * 获取真正显示中的 view
     * ========================================================
     */

    UIView *view =
        self.view;


    if (!view) {

        NSLog(
            @"[CowbellTest] self.view = nil"
        );

        return;
    }


    NSLog(
        @"[CowbellTest] view=%@ bounds=%@ window=%@",
        view,
        NSStringFromCGRect(view.bounds),
        view.window
    );


    /*
     * ========================================================
     * 创建百分比 Label
     * ========================================================
     */

    UILabel *label =
        [view viewWithTag:kPercentTag];


    if (!label) {

        label =
            [[UILabel alloc] init];


        label.tag =
            kPercentTag;


        label.textAlignment =
            NSTextAlignmentCenter;


        label.font =
            [UIFont systemFontOfSize:
                10.0
                weight:UIFontWeightSemibold];


        label.textColor =
            [UIColor whiteColor];


        label.layer.allowsGroupBlending =
            NO;


        label.layer.allowsGroupOpacity =
            YES;


        /*
         * 保留 Cowbell 的镂空效果
         */

        label.layer.compositingFilter =
            kCAFilterDestOut;


        [view addSubview:label];


        NSLog(
            @"[CowbellTest] Label CREATED"
        );
    }


    /*
     * ========================================================
     * 读取真实电量
     * ========================================================
     */

    UIDevice *device =
        [UIDevice currentDevice];


    device.batteryMonitoringEnabled =
        YES;


    float level =
        device.batteryLevel;


    NSLog(
        @"[CowbellTest] batteryLevel=%f",
        level
    );


    if (level < 0.0f) {

        return;
    }


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
        @"[CowbellTest] Label frame=%@ text=%@",
        NSStringFromCGRect(label.frame),
        label.text
    );
}

%end