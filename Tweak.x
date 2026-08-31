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
- (UIView *)contentView;
- (void)updateCowbellState;
@end

%hook CCUIContentModuleContainerViewController

%property (nonatomic, retain) UILabel *cowbellLabel;
%property (nonatomic, retain) NSLayoutConstraint *cowbellCollapsedTopConstraint;
%property (nonatomic, retain) NSLayoutConstraint *cowbellExpandedTopConstraint;


/*
 ============================================================
                    只需要调这里
 ============================================================

 一级菜单百分比位置：

 数值越大 → 越往下
 数值越小 → 越往上

 例如：

 4.0  比 8.0 更靠上
 8.0  当前默认
 12.0 比 8.0 更靠下

 ============================================================
 */

static CGFloat const COWBELL_COLLAPSED_OFFSET = 8.0;


/*
 ============================================================
                 二级菜单独立位置
 ============================================================

 目前二级菜单百分比会隐藏。

 所以这个数值暂时不会影响你看到的结果。

 保留它，是为了让一级、二级位置从代码结构上完全独立。
 ============================================================
 */

static CGFloat const COWBELL_EXPANDED_OFFSET = 20.0;


/*
 ============================================================
                    更新电量百分比
 ============================================================
 */

%new
- (void)updateCowbellState
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCowbellState];
        });
        return;
    }

    if (!self.cowbellLabel) {
        return;
    }

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

- (void)viewDidLoad
{
    %orig;

    if ([self.moduleIdentifier
         isEqualToString:@"com.apple.control-center.LowPowerModule"]) {

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }
}


/*
 ============================================================
                   创建百分比 Label
 ============================================================
 */

- (void)viewDidLayoutSubviews
{
    %orig;

    if (![self.moduleIdentifier
          isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        return;
    }

    UIView *targetContainer =
        [self respondsToSelector:@selector(contentView)]
        ? [self contentView]
        : self.view;

    if (!targetContainer) {
        return;
    }


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
                    一级菜单独立位置
         ====================================================
         */

        self.cowbellCollapsedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:targetContainer.centerYAnchor
             constant:COWBELL_COLLAPSED_OFFSET];


        /*
         ====================================================
                    二级菜单独立位置
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
                         一级显示
         ----------------------------------------------------
         */

        label.hidden = NO;
        label.alpha = 1.0;
    }


    /*
     ========================================================
     这里只负责刷新文字。

     不在这里改变：

     hidden
     alpha
     一级位置
     二级位置

     防止 layoutSubviews 反复触发导致跳动。
     ========================================================
     */

    [self updateCowbellState];
}


/*
 ============================================================
                       ViewDidAppear
 ============================================================
 */

- (void)viewDidAppear:(BOOL)animated
{
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

- (void)viewDidDisappear:(BOOL)animated
{
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
                 一级 <-> 二级菜单同步
 ============================================================
 */

- (void)willTransitionToExpandedContentMode:(BOOL)expanded
{
    %orig(expanded);

    if (![self.moduleIdentifier
          isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        return;
    }

    if (!self.cowbellLabel) {
        return;
    }


    /*
     ========================================================
                    一级 → 二级
     ========================================================

     1. 切换到二级独立位置
     2. 百分比同步淡出
     3. 动画结束后 hidden = YES

     ========================================================
     */

    if (expanded) {

        self.cowbellCollapsedTopConstraint.active = NO;

        self.cowbellExpandedTopConstraint.active = YES;

        self.cowbellLabel.hidden = NO;

        UIView *container = self.cowbellLabel.superview;

        if (container) {

            [UIView animateWithDuration:0.25
                                  delay:0
                                options:
                UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                                 [container layoutIfNeeded];
                                 self.cowbellLabel.alpha = 0.0;
                             }
                             completion:^(BOOL finished) {
                                 self.cowbellLabel.alpha = 0.0;
                                 self.cowbellLabel.hidden = YES;
                             }];
        }

        return;
    }


    /*
     ========================================================
                    二级 → 一级
     ========================================================

     1. 先解除 hidden
     2. alpha 保持 0
     3. 切回一级独立位置
     4. 跟随转场同步淡入

     ========================================================
     */

    self.cowbellExpandedTopConstraint.active = NO;

    self.cowbellCollapsedTopConstraint.active = YES;

    self.cowbellLabel.hidden = NO;

    self.cowbellLabel.alpha = 0.0;

    UIView *container = self.cowbellLabel.superview;

    if (!container) {
        self.cowbellLabel.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.25
                          delay:0
                        options:
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         [container layoutIfNeeded];
                         self.cowbellLabel.alpha = 1.0;
                     }
                     completion:^(BOOL finished) {
                         self.cowbellLabel.hidden = NO;
                         self.cowbellLabel.alpha = 1.0;
                     }];
}

%end

#pragma clang diagnostic pop