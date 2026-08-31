#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end


/*
 ============================================================
             低电量模块 Controller
 ============================================================
 */

@interface CCUIContentModuleContainerViewController : UIViewController

@property (nonatomic, readonly, copy) NSString *moduleIdentifier;

- (UIView *)contentView;

@end


/*
 ============================================================
             低电量模块实际 Container
 ============================================================
 */

@interface CCUIContentModuleContainerView : UIView

@property (nonatomic, strong) NSString *moduleIdentifier;

@end



/*
 ============================================================
                  Controller Hook
 ============================================================
 */

%hook CCUIContentModuleContainerViewController


%property (nonatomic, assign) BOOL cbCowbellExpanded;


/*
 ============================================================
                    一级 / 二级状态
 ============================================================
 */

- (void)willTransitionToExpandedContentMode:(BOOL)expanded
{
    %orig(expanded);


    /*
     --------------------------------------------------------
                     只处理低电量模块
     --------------------------------------------------------
     */

    if (![self.moduleIdentifier
         isEqualToString:
         @"com.apple.control-center.LowPowerModule"]) {

        return;
    }


    /*
     --------------------------------------------------------
                     保存当前状态
     --------------------------------------------------------
     */

    self.cbCowbellExpanded = expanded;


    /*
     --------------------------------------------------------
                   找到实际 ContentView
     --------------------------------------------------------
     */

    UIView *content =
        [self respondsToSelector:@selector(contentView)]
        ? [self contentView]
        : nil;


    if (!content) {
        return;
    }


    /*
     --------------------------------------------------------
                    找到百分比 Label
     --------------------------------------------------------
     */

    UILabel *label = nil;


    if ([content isKindOfClass:
         [CCUIContentModuleContainerView class]]) {

        CCUIContentModuleContainerView *container =
            (CCUIContentModuleContainerView *)content;


        label =
            [container valueForKey:@"cbPercentLabel"];
    }


    /*
     --------------------------------------------------------
                 如果外面还有一层 Container
     --------------------------------------------------------
     */

    if (!label) {

        for (UIView *subview in content.subviews) {

            if ([subview isKindOfClass:
                 [CCUIContentModuleContainerView class]]) {

                CCUIContentModuleContainerView *container =
                    (CCUIContentModuleContainerView *)subview;


                label =
                    [container valueForKey:@"cbPercentLabel"];


                if (label) {
                    break;
                }
            }
        }
    }


    if (!label) {
        return;
    }


    /*
 ============================================================
                       一级 → 二级
 ============================================================
 */

    if (expanded) {

        /*
         ----------------------------------------------------
                    立即隐藏百分比
         ----------------------------------------------------
         */

        label.hidden = YES;
        label.alpha = 0.0;

        return;
    }


    /*
 ============================================================
                       二级 → 一级
 ============================================================
 */

    /*
     --------------------------------------------------------
       先恢复 Label，但保持透明。

       这样百分比不会晚于电池图标出现。
     --------------------------------------------------------
     */

    label.hidden = NO;
    label.alpha = 0.0;


    [UIView animateWithDuration:0.20
                          delay:0.0
                        options:
         UIViewAnimationOptionBeginFromCurrentState |
         UIViewAnimationOptionAllowUserInteraction
                     animations:^{

        label.alpha = 1.0;

    }
                     completion:^(BOOL finished) {

        label.hidden = NO;
        label.alpha = 1.0;
    }];
}


%end



/*
 ============================================================
                 Container View Hook
 ============================================================
 */

%hook CCUIContentModuleContainerView


%property (nonatomic, strong) UILabel *cbPercentLabel;

%property (nonatomic, assign) BOOL cbCowbellHidden;



/*
 ============================================================
                 判断低电量模块
 ============================================================
 */

%new
- (BOOL)cb_isLowPowerModule
{
    if ([self respondsToSelector:@selector(moduleIdentifier)]) {

        NSString *modID =
            [self performSelector:@selector(moduleIdentifier)];


        if ([modID isEqualToString:
             @"com.apple.control-center.LowPowerModule"] ||
            [modID containsString:@"LowPowerModule"]) {

            return YES;
        }
    }


    UIResponder *responder = self;


    while (responder) {

        NSString *clsName =
            NSStringFromClass([responder class]);


        if ([clsName containsString:
             @"CCUILowPowerModeModule"]) {

            return YES;
        }


        responder =
            [responder nextResponder];
    }


    return NO;
}



/*
 ============================================================
                     更新百分比
 ============================================================
 */

%new
- (void)cb_updatePercentText
{
    dispatch_async(dispatch_get_main_queue(), ^{

        if (!self.cbPercentLabel) {
            return;
        }


        float level =
            [UIDevice currentDevice].batteryLevel;


        int percent =
            (level >= 0)
            ? (int)round(level * 100.0f)
            : 100;


        self.cbPercentLabel.text =
            [NSString stringWithFormat:@"%d%%", percent];


        BOOL isLowPowerMode =
            [NSProcessInfo processInfo].isLowPowerModeEnabled;


        if (isLowPowerMode) {

            self.cbPercentLabel.textColor =
                [UIColor blackColor];

        } else {

            self.cbPercentLabel.textColor =
                [UIColor whiteColor];
        }
    });
}



/*
 ============================================================
                    Layout
 ============================================================
 */

- (void)layoutSubviews
{
    %orig;


    /*
     --------------------------------------------------------
                   非低电量模块
     --------------------------------------------------------
     */

    if (![self cb_isLowPowerModule]) {

        if (self.cbPercentLabel) {
            self.cbPercentLabel.hidden = YES;
        }

        return;
    }


    CGFloat width =
        self.bounds.size.width;


    CGFloat height =
        self.bounds.size.height;


    if (width <= 0 ||
        height <= 0 ||
        width > 100 ||
        height > 100) {

        return;
    }


    /*
     ========================================================
                   找到自己的 Controller
     ========================================================
     */

    BOOL expanded = NO;


    UIResponder *responder =
        [self nextResponder];


    while (responder) {

        if ([responder
             isKindOfClass:
             [CCUIContentModuleContainerViewController class]]) {

            CCUIContentModuleContainerViewController *controller =
                (CCUIContentModuleContainerViewController *)responder;


            expanded =
                controller.cbCowbellExpanded;


            break;
        }


        responder =
            [responder nextResponder];
    }


    /*
 ============================================================
                     二级状态
 ============================================================
 */

    if (expanded) {

        if (self.cbPercentLabel) {

            self.cbPercentLabel.hidden = YES;
            self.cbPercentLabel.alpha = 0.0;
        }

        return;
    }



    /*
 ============================================================
                 电池图标完全不动
 ============================================================
 */

    for (UIView *subview in self.subviews) {

        if (subview != self.cbPercentLabel) {

            subview.transform =
                CGAffineTransformIdentity;
        }
    }



    /*
 ============================================================
                  创建百分比 Label
 ============================================================
 */

    if (!self.cbPercentLabel) {

        UILabel *lab =
            [[UILabel alloc]
             initWithFrame:
             CGRectMake(0,
                        height - 22,
                        width,
                        12)];


        lab.font =
            [UIFont systemFontOfSize:10
                              weight:UIFontWeightBold];


        lab.textAlignment =
            NSTextAlignmentCenter;


        lab.userInteractionEnabled = NO;


        lab.backgroundColor =
            [UIColor clearColor];


        /*
         ====================================================
                     Cowbell 镂空效果
         ====================================================
         */

        CAFilter *filter =
            [CAFilter filterWithType:kCAFilterDestOut];


        lab.layer.filters =
            @[filter];


        self.cbPercentLabel =
            lab;


        [self addSubview:lab];


        /*
         ----------------------------------------------------
                       开启电量监控
         ----------------------------------------------------
         */

        [UIDevice currentDevice].batteryMonitoringEnabled =
            YES;


        /*
         ----------------------------------------------------
                       电量变化
         ----------------------------------------------------
         */

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(cb_updatePercentText)
                   name:UIDeviceBatteryLevelDidChangeNotification
                 object:nil];


        /*
         ----------------------------------------------------
                       低电量模式变化
         ----------------------------------------------------
         */

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(cb_updatePercentText)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];
    }


    /*
 ============================================================
                 一级菜单百分比位置
 ============================================================
 */

    self.cbPercentLabel.frame =
        CGRectMake(0,
                   height - 22,
                   width,
                   12);


    self.cbPercentLabel.hidden = NO;

    self.cbPercentLabel.alpha = 1.0;


    /*
 ------------------------------------------------------------
 注意：

 不使用 bringSubviewToFront。

 保持系统原来的 View 层级，
 避免其他模块二级菜单的毛玻璃出现后，
 百分比跑到毛玻璃下面。
 ------------------------------------------------------------
 */


    [self cb_updatePercentText];
}


%end


#pragma clang diagnostic pop