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

- (UIView *)contentView;
- (void)updateCowbellState;

@end


%hook CCUIContentModuleContainerViewController

%property (nonatomic, retain) UILabel *cowbellLabel;


/*
 ============================================================
                    一级菜单百分比位置
 ============================================================

 只调这个数字。

 数值越大：
     百分比越往下

 数值越小：
     百分比越往上

 例如：

     4.0  往上
     6.0  往上一点
     8.0  当前
    10.0  往下一点

 ============================================================
 */

static CGFloat const COWBELL_COLLAPSED_OFFSET = 8.0;


/*
 ============================================================
                    更新百分比
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


    /*
     --------------------------------------------------------
                       获取电量
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
                       低电量模式颜色
     --------------------------------------------------------
     */

    BOOL isLPMOn =
        [[NSProcessInfo processInfo]
         isLowPowerModeEnabled];


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

- (void)viewDidLoad
{
    %orig;


    if ([self.moduleIdentifier
         isEqualToString:
         @"com.apple.control-center.LowPowerModule"]) {

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }
}


/*
 ============================================================
                       创建百分比
 ============================================================
 */

- (void)viewDidLayoutSubviews
{
    %orig;


    if (![self.moduleIdentifier
          isEqualToString:
          @"com.apple.control-center.LowPowerModule"]) {

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
                    第一次创建百分比
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
         ====================================================
                       Cowbell 镂空效果
         ====================================================
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
                    一级菜单独立位置
         ====================================================
         */

        [NSLayoutConstraint activateConstraints:@[

            [label.centerXAnchor
             constraintEqualToAnchor:
             targetContainer.centerXAnchor],

            [label.centerYAnchor
             constraintEqualToAnchor:
             targetContainer.centerYAnchor
             constant:COWBELL_COLLAPSED_OFFSET]

        ]];


        /*
         ====================================================
                       开启电量监控
         ====================================================
         */

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }


    /*
     ========================================================
     注意：

     这里故意没有：

         bringSubviewToFront

     这是这次修复的关键。

     百分比保持在原来的 View 层级中，
     这样打开其他模块二级菜单时，
     系统毛玻璃可以正常覆盖它。

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
         isEqualToString:
         @"com.apple.control-center.LowPowerModule"]) {


        NSNotificationCenter *nc =
            [NSNotificationCenter defaultCenter];


        /*
         ----------------------------------------------------
                    防止重复注册
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
         isEqualToString:
         @"com.apple.control-center.LowPowerModule"]) {


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
                  一级 <-> 二级菜单
 ============================================================

 这里只处理低电量模块自己的展开。

 一级：
     百分比正常显示

 二级：
     百分比隐藏

 返回一级：
     百分比同步恢复

 ============================================================
 */

- (void)willTransitionToExpandedContentMode:(BOOL)expanded
{
    %orig(expanded);


    if (![self.moduleIdentifier
          isEqualToString:
          @"com.apple.control-center.LowPowerModule"]) {

        return;
    }


    if (!self.cowbellLabel) {
        return;
    }


    /*
     ========================================================
                         一级 → 二级
     ========================================================
     */

    if (expanded) {

        /*
         ----------------------------------------------------
             先同步淡出，再彻底隐藏
         ----------------------------------------------------
         */

        [UIView animateWithDuration:0.20
                              delay:0.0
                            options:
             UIViewAnimationOptionBeginFromCurrentState |
             UIViewAnimationOptionAllowUserInteraction
                         animations:^{

            self.cowbellLabel.alpha = 0.0;

        }
                         completion:^(BOOL finished) {

            self.cowbellLabel.hidden = YES;
            self.cowbellLabel.alpha = 0.0;
        }];


        return;
    }


    /*
     ========================================================
                         二级 → 一级
     ========================================================
     */

    /*
     --------------------------------------------------------
       先解除 hidden，但保持透明。

       这样不会出现：

           图标先出现
           ↓
           百分比晚一点才出现

       而是百分比已经准备好，
       跟随一级菜单转场一起出现。
     --------------------------------------------------------
     */

    self.cowbellLabel.hidden = NO;
    self.cowbellLabel.alpha = 0.0;


    [UIView animateWithDuration:0.20
                          delay:0.0
                        options:
         UIViewAnimationOptionBeginFromCurrentState |
         UIViewAnimationOptionAllowUserInteraction
                     animations:^{

        self.cowbellLabel.alpha = 1.0;

    }
                     completion:^(BOOL finished) {

        self.cowbellLabel.hidden = NO;
        self.cowbellLabel.alpha = 1.0;
    }];
}


%end


#pragma clang diagnostic pop