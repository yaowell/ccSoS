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
 百分比最终完全隐藏。

 一级位置单独控制，不影响二级隐藏逻辑。
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
         isEqualToString:
         @"com.apple.control-center.LowPowerModule"]) {

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
          isEqualToString:
          @"com.apple.control-center.LowPowerModule"]) {

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
             constraintEqualToAnchor:
             targetContainer.centerYAnchor
             constant:COWBELL_COLLAPSED_OFFSET];


        /*
         ====================================================
                       二级菜单位置
         ====================================================

         这个约束保留，只是为了保持原来的
         一级 / 二级转场结构。

         二级最终会完全隐藏。
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
                    默认显示状态
         ----------------------------------------------------
         */

        label.alpha =
            self.cowbellIsExpanded ? 0.0 : 1.0;

        label.hidden =
            self.cowbellIsExpanded;
    }


    /*
     ========================================================
                     二级状态保护
     ========================================================

     防止系统在二级菜单期间重新 layout，
     又把百分比显示出来。
     ========================================================
     */

    if (self.cowbellIsExpanded) {

        self.cowbellLabel.hidden = YES;
        self.cowbellLabel.alpha = 0.0;

    } else {

        /*
         ----------------------------------------------------
                         一级菜单
         ----------------------------------------------------
         */

        self.cowbellLabel.hidden = NO;
        self.cowbellLabel.alpha = 1.0;
    }


    /*
     ========================================================
                    刷新电量
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
              一级 <-> 二级菜单同步转场
 ============================================================
 */

- (void)willTransitionToExpandedContentMode:(BOOL)expanded {

    %orig(expanded);


    if (![self.moduleIdentifier
          isEqualToString:
          @"com.apple.control-center.LowPowerModule"]) {

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
                       获取容器
     ========================================================
     */

    UIView *container =
        self.cowbellLabel.superview;


    if (!container) return;


    /*
     ========================================================
                     二级 -> 一级
     ========================================================

     先解除 hidden。

     alpha 保持 0，
     因此不会突然出现百分比。

     然后和一级菜单一起淡入。
     ========================================================
     */

    if (!expanded) {

        self.cowbellLabel.hidden = NO;
        self.cowbellLabel.alpha = 0.0;
    }


    /*
     ========================================================
                       同步动画
     ========================================================
     */

    [UIView animateWithDuration:0.25
                          delay:0.0
                        options:
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction |
        UIViewAnimationOptionCurveEaseInOut
                     animations:^{

        /*
         ----------------------------------------------------
                       应用新的位置
         ----------------------------------------------------
         */

        [container layoutIfNeeded];


        /*
         ----------------------------------------------------
                    一级显示 / 二级隐藏
         ----------------------------------------------------
         */

        self.cowbellLabel.alpha =
            expanded ? 0.0 : 1.0;

    }
                     completion:^(BOOL finished) {

        /*
         ====================================================
                         一级 -> 二级
         ====================================================

         动画结束后彻底 hidden。
         ====================================================
         */

        if (expanded) {

            self.cowbellLabel.hidden = YES;
            self.cowbellLabel.alpha = 0.0;

        } else {

        /*
         ====================================================
                         二级 -> 一级
         ====================================================

         最终恢复显示。
         ====================================================
         */

            self.cowbellLabel.hidden = NO;
            self.cowbellLabel.alpha = 1.0;
        }
    }];
}


%end


#pragma clang diagnostic pop