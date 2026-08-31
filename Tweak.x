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

// 一级菜单位置
@property (nonatomic, retain) NSLayoutConstraint *cowbellCollapsedTopConstraint;

// 二级菜单位置
@property (nonatomic, retain) NSLayoutConstraint *cowbellExpandedTopConstraint;

// 当前是否为二级菜单
@property (nonatomic, assign) BOOL cowbellIsExpanded;

- (UIView *)contentView;
- (void)updateCowbellState;

@end


%hook CCUIContentModuleContainerViewController

%property (nonatomic, retain) UILabel *cowbellLabel;

%property (nonatomic, retain)
NSLayoutConstraint *cowbellCollapsedTopConstraint;

%property (nonatomic, retain)
NSLayoutConstraint *cowbellExpandedTopConstraint;

%property (nonatomic, assign)
BOOL cowbellIsExpanded;


/*
 ============================================================
                  Cowbell 位置参数
 ============================================================

 只改这里。

 ------------------------------------------------------------
 一级菜单
 ------------------------------------------------------------

 数字越大 = 百分比越往下
 数字越小 = 百分比越往上

 ------------------------------------------------------------
 二级菜单
 ------------------------------------------------------------

 二级菜单目前会隐藏百分比。

 这个参数仍然保留。
 如果以后想让二级菜单显示百分比，可以直接利用。

 ============================================================
 */

// 一级菜单百分比位置
static CGFloat const COWBELL_COLLAPSED_OFFSET = 8.0;

// 二级菜单百分比位置
static CGFloat const COWBELL_EXPANDED_OFFSET = 20.0;


/*
 ============================================================
                    电量百分比刷新
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


    /*
     --------------------------------------------------------
     读取当前电量
     --------------------------------------------------------
     */

    float level =
        [[UIDevice currentDevice] batteryLevel];

    float safeLevel =
        (level < 0) ? 1.0 : level;

    int battery =
        (int)round(safeLevel * 100);


    self.cowbellLabel.text =
        [NSString stringWithFormat:@"%i%%", battery];


    /*
     --------------------------------------------------------
     低电量模式状态
     --------------------------------------------------------
     */

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

        /*
         ----------------------------------------------------
         默认进入一级菜单状态
         ----------------------------------------------------
         */

        self.cowbellIsExpanded = NO;
    }
}


/*
 ============================================================
                  创建 Cowbell 百分比
 ============================================================

 重要：

 这里只创建一次 Label。

 不在这里判断一级 / 二级。

 不在这里切换 alpha。

 不在这里反复修改位置。

 这样可以避免：

    电池图标出现
        ↓
    viewDidLayoutSubviews
        ↓
    百分比重新创建
        ↓
    百分比晚出现

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


        /*
         ----------------------------------------------------
         字体
         ----------------------------------------------------
         */

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

        label.translatesAutoresizingMaskIntoConstraints = NO;


        [targetContainer addSubview:label];


        self.cowbellLabel = label;


        /*
         ====================================================
                     一级菜单位置约束
         ====================================================
         */

        self.cowbellCollapsedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:
             targetContainer.centerYAnchor
             constant:COWBELL_COLLAPSED_OFFSET];


        /*
         ====================================================
                     二级菜单位置约束
         ====================================================

         当前二级菜单会隐藏百分比。

         但仍然保留独立约束。
         ====================================================
         */

        self.cowbellExpandedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:
             targetContainer.centerYAnchor
             constant:COWBELL_EXPANDED_OFFSET];


        /*
         ====================================================
                       默认使用一级位置
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
         ====================================================
                         默认显示
         ====================================================

         一级菜单第一次出现时：

             电池图标
                 +
             百分比

         ====================================================
         */

        label.alpha = 1.0;
    }


    /*
     ========================================================
     这里只刷新文字。

     不切换：

         一级 / 二级位置

     不切换：

         alpha

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


        /*
         ----------------------------------------------------
         清理旧 Observer
         ----------------------------------------------------
         */

        [nc removeObserver:self
                      name:NSProcessInfoPowerStateDidChangeNotification
                    object:nil];


        [nc removeObserver:self
                      name:UIDeviceBatteryLevelDidChangeNotification
                    object:nil];


        /*
         ----------------------------------------------------
         低电量模式变化
         ----------------------------------------------------
         */

        [nc addObserver:self
               selector:@selector(updateCowbellState)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];


        /*
         ----------------------------------------------------
         电量变化
         ----------------------------------------------------
         */

        [nc addObserver:self
               selector:@selector(updateCowbellState)
                   name:UIDeviceBatteryLevelDidChangeNotification
                 object:nil];


        /*
         ----------------------------------------------------
         立即刷新
         ----------------------------------------------------
         */

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
              一级 <-> 二级菜单同步转场
 ============================================================

 这是整个版本最重要的部分。

 ------------------------------------------------------------
 一级 -> 二级
 ------------------------------------------------------------

     电池图标开始进入二级动画
             +
     百分比同时开始淡出

 ------------------------------------------------------------
 二级 -> 一级
 ------------------------------------------------------------

     电池图标开始回到一级动画
             +
     百分比同时开始淡入

 ------------------------------------------------------------

 重点：

 不在 viewDidLayoutSubviews 中切换。

 只在这里切换。

 ============================================================
 */

- (void)willTransitionToExpandedContentMode:(BOOL)expanded {

    %orig(expanded);


    if (![self.moduleIdentifier
          isEqualToString:@"com.apple.control-center.LowPowerModule"]) {

        return;
    }


    if (!self.cowbellLabel) return;


    /*
     ========================================================
                     保存当前状态
     ========================================================
     */

    self.cowbellIsExpanded = expanded;


    /*
     ========================================================
                     切换位置约束
     ========================================================
     */

    if (expanded) {

        /*
         ----------------------------------------------------
         一级 -> 二级
         ----------------------------------------------------
         */

        self.cowbellCollapsedTopConstraint.active = NO;

        self.cowbellExpandedTopConstraint.active = YES;

    } else {

        /*
         ----------------------------------------------------
         二级 -> 一级
         ----------------------------------------------------
         */

        self.cowbellExpandedTopConstraint.active = NO;

        self.cowbellCollapsedTopConstraint.active = YES;
    }


    /*
     ========================================================
                   与系统转场一起执行
     ========================================================

     注意：

     这里不提前把 alpha 设置成 0 / 1。

     而是把：

         位置
         +
         alpha

     放进同一个动画块。

     ========================================================
     */

    UIView *container =
        self.cowbellLabel.superview;


    if (!container) return;


    [UIView animateWithDuration:0.25
                          delay:0.0
                        options:
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction |
        UIViewAnimationOptionCurveEaseInOut
                     animations:^{

        /*
         ----------------------------------------------------
         让 AutoLayout 在当前转场动画里完成位置变化
         ----------------------------------------------------
         */

        [container layoutIfNeeded];


        /*
         ----------------------------------------------------
         一级 -> 二级

         百分比与电池图标一起淡出
         ----------------------------------------------------
         */

        self.cowbellLabel.alpha =
            expanded ? 0.0 : 1.0;

    }
                     completion:nil];
}


%end


#pragma clang diagnostic pop