#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

@interface CCUIContentModuleContainerViewController : UIViewController

@property (nonatomic, readonly, copy) NSString *moduleIdentifier;
@property (nonatomic, retain) UILabel *cowbellLabel;

@property (nonatomic, retain) NSLayoutConstraint *cowbellCollapsedTopConstraint;
@property (nonatomic, retain) NSLayoutConstraint *cowbellExpandedTopConstraint;

@property (nonatomic, assign) BOOL cowbellIsExpanded;

- (UIView *)contentView;
- (void)updateCowbellState;

@end


%hook CCUIContentModuleContainerViewController

%property (nonatomic, retain) UILabel *cowbellLabel;
%property (nonatomic, retain) NSLayoutConstraint *cowbellCollapsedTopConstraint;
%property (nonatomic, retain) NSLayoutConstraint *cowbellExpandedTopConstraint;
%property (nonatomic, assign) BOOL cowbellIsExpanded;


/*
 ============================================================
                    Cowbell 位置参数
 ============================================================

 一级菜单百分比位置：

 数字越大 = 越往下
 数字越小 = 越往上

 例如：

 8.0
 6.0
 4.0
 2.0
 0.0

 ------------------------------------------------------------

 二级菜单目前隐藏百分比。

 这个参数先保留，不影响一级菜单。
 ============================================================
 */

static CGFloat const COWBELL_COLLAPSED_OFFSET = 8.0;

static CGFloat const COWBELL_EXPANDED_OFFSET = 20.0;


/*
 ============================================================
                    电量刷新
 ============================================================
 */

%new
- (void)updateCowbellState {

    if (![NSThread isMainThread]) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCowbellState];
        });

        return;
    }

    if (!self.cowbellLabel) return;


    float level =
        [[UIDevice currentDevice] batteryLevel];


    float safeLevel =
        (level < 0) ? 1.0 : level;


    int battery =
        (int)round(safeLevel * 100);


    self.cowbellLabel.text =
        [NSString stringWithFormat:@"%i%%", battery];


    BOOL isLPMOn =
        [[NSProcessInfo processInfo] isLowPowerModeEnabled];


    self.cowbellLabel.textColor =
        isLPMOn
        ? [UIColor blackColor]
        : [UIColor whiteColor];
}


/*
 ============================================================
                        ViewDidLoad
 ============================================================
 */

- (void)viewDidLoad {

    %orig;


    if ([self.moduleIdentifier
         isEqualToString:@"com.apple.control-center.LowPowerModule"]) {

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        self.cowbellIsExpanded = NO;
    }
}


/*
 ============================================================
                    创建 Cowbell Label
 ============================================================
 */

- (void)viewDidLayoutSubviews {

    %orig;


    if (![self.moduleIdentifier
          isEqualToString:@"com.apple.control-center.LowPowerModule"]) {

        return;
    }


    UIView *targetContainer =
        [self respondsToSelector:@selector(contentView)]
        ? [self contentView]
        : self.view;


    if (!targetContainer) return;


    /*
     ========================================================
                      第一次创建 Label
     ========================================================
     */

    if (!self.cowbellLabel) {

        UILabel *label =
            [[UILabel alloc] init];


        label.font =
            [UIFont systemFontOfSize:10
                              weight:UIFontWeightBold];


        label.textAlignment =
            NSTextAlignmentCenter;


        label.userInteractionEnabled = NO;


        label.backgroundColor =
            [UIColor clearColor];


        label.textColor =
            [UIColor whiteColor];


        /*
         ----------------------------------------------------
                       Cowbell 镂空效果
         ----------------------------------------------------
         */

        CAFilter *filter =
            [CAFilter filterWithType:kCAFilterDestOut];


        label.layer.filters =
            @[filter];


        /*
         ----------------------------------------------------
                         AutoLayout
         ----------------------------------------------------
         */

        label.translatesAutoresizingMaskIntoConstraints =
            NO;


        [targetContainer addSubview:label];


        self.cowbellLabel = label;


        /*
         ====================================================
                    一级菜单位置
         ====================================================
         */

        self.cowbellCollapsedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:
             targetContainer.centerYAnchor
             constant:COWBELL_COLLAPSED_OFFSET];


        /*
         ====================================================
                    二级菜单位置
         ====================================================
         */

        self.cowbellExpandedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:
             targetContainer.centerYAnchor
             constant:COWBELL_EXPANDED_OFFSET];


        /*
         ====================================================
                     默认一级菜单
         ====================================================
         */

        self.cowbellCollapsedTopConstraint.active = YES;

        self.cowbellExpandedTopConstraint.active = NO;


        /*
         ----------------------------------------------------
                         水平居中
         ----------------------------------------------------
         */

        [NSLayoutConstraint activateConstraints:@[

            [label.centerXAnchor
             constraintEqualToAnchor:
             targetContainer.centerXAnchor]

        ]];


        /*
         ----------------------------------------------------
                         一级显示
         ----------------------------------------------------
         */

        label.hidden = NO;

        label.alpha = 1.0;
    }


    /*
     ========================================================
     注意：

     这里绝对不处理：

         alpha

     也不处理：

         hidden

     也不切换：

         一级 / 二级约束

     ========================================================
     */

    [self updateCowbellState];
}


/*
 ============================================================
                       ViewDidAppear
 ============================================================
 */

- (void)viewDidAppear:(BOOL)animated {

    %orig(animated);


    if ([self.moduleIdentifier
         isEqualToString:@"com.apple.control-center.LowPowerModule"]) {


        NSNotificationCenter *nc =
            [NSNotificationCenter defaultCenter];


        [nc removeObserver:self
                      name:NSProcessInfoPowerStateDidChangeNotification
                    object:nil];


        [nc removeObserver:self
                      name:UIDeviceBatteryLevelDidChangeNotification
                    object:nil];


        [nc addObserver:self
               selector:@selector(updateCowbellState)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];


        [nc addObserver:self
               selector:@selector(updateCowbellState)
                   name:UIDeviceBatteryLevelDidChangeNotification
                 object:nil];


        [self updateCowbellState];
    }
}


/*
 ============================================================
                    ViewDidDisappear
 ============================================================
 */

- (void)viewDidDisappear:(BOOL)animated {

    %orig(animated);


    if ([self.moduleIdentifier
         isEqualToString:@"com.apple.control-center.LowPowerModule"]) {


        NSNotificationCenter *nc =
            [NSNotificationCenter defaultCenter];


        [nc removeObserver:self
                      name:NSProcessInfoPowerStateDidChangeNotification
                    object:nil];


        [nc removeObserver:self
                      name:UIDeviceBatteryLevelDidChangeNotification
                    object:nil];
    }
}


/*
 ============================================================
                  一级 -> 二级 / 二级 -> 一级
 ============================================================

 这里是唯一处理：

     位置
     hidden
     alpha

 的地方。

 ============================================================
 */

- (void)willTransitionToExpandedContentMode:(BOOL)expanded {

    %orig(expanded);


    if (![self.moduleIdentifier
          isEqualToString:@"com.apple.control-center.LowPowerModule"]) {

        return;
    }


    if (!self.cowbellLabel) return;


    UIView *container =
        self.cowbellLabel.superview;


    if (!container) return;


    /*
     ========================================================
                       保存展开状态
     ========================================================
     */

    self.cowbellIsExpanded = expanded;


    /*
     ========================================================
                     一级 -> 二级
     ========================================================
     */

    if (expanded) {


        /*
         ----------------------------------------------------
                       切到二级位置
         ----------------------------------------------------
         */

        self.cowbellCollapsedTopConstraint.active = NO;

        self.cowbellExpandedTopConstraint.active = YES;


        /*
         ----------------------------------------------------
         百分比在整个转场过程中淡出
         ----------------------------------------------------
         */

        self.cowbellLabel.hidden = NO;


        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:
             UIViewAnimationOptionBeginFromCurrentState |
             UIViewAnimationOptionAllowUserInteraction |
             UIViewAnimationOptionCurveEaseInOut
                         animations:^{

            [container layoutIfNeeded];

            self.cowbellLabel.alpha = 0.0;

        }
                         completion:^(BOOL finished) {

            /*
             ------------------------------------------------
             二级最终状态：

                 hidden = YES

             这样二级菜单不会再显示百分比。
             ------------------------------------------------
             */

            self.cowbellLabel.alpha = 0.0;

            self.cowbellLabel.hidden = YES;
        });


    }

    /*
     ========================================================
                     二级 -> 一级
     ========================================================
     */

    else {


        /*
         ----------------------------------------------------
                       切回一级位置
         ----------------------------------------------------
         */

        self.cowbellExpandedTopConstraint.active = NO;

        self.cowbellCollapsedTopConstraint.active = YES;


        /*
         ----------------------------------------------------
         非常关键：

         在动画开始之前：

             hidden = NO
             alpha = 0

         Label 本身已经存在。

         所以不是“重新创建百分比”。
         ----------------------------------------------------
         */

        self.cowbellLabel.hidden = NO;

        self.cowbellLabel.alpha = 0.0;


        /*
         ----------------------------------------------------
                       和转场同步出现
         ----------------------------------------------------
         */

        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:
             UIViewAnimationOptionBeginFromCurrentState |
             UIViewAnimationOptionAllowUserInteraction |
             UIViewAnimationOptionCurveEaseInOut
                         animations:^{

            [container layoutIfNeeded];

            self.cowbellLabel.alpha = 1.0;

        }
                         completion:^(BOOL finished) {

            /*
             ------------------------------------------------
             一级最终状态：

                 hidden = NO
                 alpha = 1
             ------------------------------------------------
             */

            self.cowbellLabel.hidden = NO;

            self.cowbellLabel.alpha = 1.0;
        });
    }
}


%end


#pragma clang diagnostic pop