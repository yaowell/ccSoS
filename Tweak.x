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

 一级菜单：
 数字越大 = 百分比越往下
 数字越小 = 百分比越往上

 二级菜单：
 数字越大 = 百分比越往下

 两个位置完全独立。
 ============================================================
 */

static CGFloat const COWBELL_COLLAPSED_OFFSET = 8.0;
static CGFloat const COWBELL_EXPANDED_OFFSET = 20.0;


/*
 ============================================================
                    更新电量百分比
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

    float level = [[UIDevice currentDevice] batteryLevel];

    float safeLevel = (level < 0) ? 1.0 : level;

    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text =
        [NSString stringWithFormat:@"%i%%", battery];

    BOOL isLPMOn =
        [[NSProcessInfo processInfo] isLowPowerModeEnabled];

    self.cowbellLabel.textColor =
        isLPMOn ? [UIColor blackColor] : [UIColor whiteColor];
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

 这里只负责：

 1. 创建 Label
 2. 创建一级位置约束
 3. 创建二级位置约束
 4. 刷新电量

 不在这里切换一级 / 二级状态。
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

        UILabel *label = [[UILabel alloc] init];

        label.font =
            [UIFont systemFontOfSize:10
                              weight:UIFontWeightBold];

        label.textAlignment = NSTextAlignmentCenter;

        label.userInteractionEnabled = NO;

        label.backgroundColor = [UIColor clearColor];

        label.textColor = [UIColor whiteColor];


        /*
         ----------------------------------------------------
                       Cowbell 镂空效果
         ----------------------------------------------------
         */

        CAFilter *filter =
            [CAFilter filterWithType:kCAFilterDestOut];

        label.layer.filters = @[filter];


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
                       一级菜单位置
         ====================================================
         */

        self.cowbellCollapsedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:targetContainer.centerYAnchor
             constant:COWBELL_COLLAPSED_OFFSET];


        /*
         ====================================================
                       二级菜单位置
         ====================================================
         */

        self.cowbellExpandedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:targetContainer.centerYAnchor
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
             constraintEqualToAnchor:targetContainer.centerXAnchor]
        ]];


        /*
         ----------------------------------------------------
                     一级菜单默认显示
         ----------------------------------------------------
         */

        label.alpha = 1.0;
    }


    /*
     ========================================================
     这里只刷新电量。

     不在这里修改：

         alpha

     不在这里修改：

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
              一级 <-> 二级菜单同步转场
 ============================================================

 一级菜单：
     百分比显示

 二级菜单：
     百分比隐藏

 关键：

 百分比的 alpha 和位置在同一个转场动画中处理。

 二级 -> 一级：

     alpha 从 0 -> 1
     位置切回一级位置

 一级 -> 二级：

     alpha 从 1 -> 0
     位置切到二级位置

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
     --------------------------------------------------------
                       保存状态
     --------------------------------------------------------
     */

    self.cowbellIsExpanded = expanded;


    /*
     ========================================================
                       切换位置
     ========================================================
     */

    if (expanded) {

        // 一级 -> 二级

        self.cowbellCollapsedTopConstraint.active = NO;

        self.cowbellExpandedTopConstraint.active = YES;

    } else {

        // 二级 -> 一级

        self.cowbellExpandedTopConstraint.active = NO;

        self.cowbellCollapsedTopConstraint.active = YES;
    }


    /*
     ========================================================
                  同步执行位置 + 显示状态
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
                       立即应用新位置
         ----------------------------------------------------
         */

        [container layoutIfNeeded];


        /*
         ----------------------------------------------------
                     二级隐藏 / 一级显示
         ----------------------------------------------------
         */

        self.cowbellLabel.alpha =
            expanded ? 0.0 : 1.0;

    }
                     completion:nil];
}


%end


#pragma clang diagnostic pop