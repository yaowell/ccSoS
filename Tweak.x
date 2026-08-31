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

// Cowbell 两套独立位置约束
@property (nonatomic, retain) NSLayoutConstraint *cowbellCollapsedTopConstraint;
@property (nonatomic, retain) NSLayoutConstraint *cowbellExpandedTopConstraint;

// 当前是否处于二级菜单
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
                    Cowbell 位置调节
 ============================================================

 一级菜单：
 数字越大 -> 百分比越往下
 数字越小 -> 百分比越往上

 二级菜单：
 数字越大 -> 百分比越往下
 数字越小 -> 百分比越往上

 两个数字互不影响。
 ============================================================
 */

// 一级菜单百分比位置
static CGFloat const COWBELL_COLLAPSED_OFFSET = 8.0;

// 二级菜单百分比位置
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


    /*
     --------------------------------------------------------
     读取电量
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

        // 初始状态一定认为是一级菜单
        self.cowbellIsExpanded = NO;
    }
}


/*
 ============================================================
                   创建 Cowbell Label
 ============================================================

 注意：

 viewDidLayoutSubviews 这里只负责：

 1. 找到容器
 2. 创建百分比 Label
 3. 创建一级 / 二级两套约束

 不在这里判断一级 / 二级。

 这样就不会因为系统反复 layout 导致百分比跳动。
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
         */

        self.cowbellExpandedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:
             targetContainer.centerYAnchor
             constant:COWBELL_EXPANDED_OFFSET];


        /*
         ====================================================
                    默认只启用一级菜单约束
         ====================================================
         */

        self.cowbellCollapsedTopConstraint.active = YES;

        self.cowbellExpandedTopConstraint.active = NO;


        /*
         ----------------------------------------------------
         水平始终居中
         ----------------------------------------------------
         */

        [NSLayoutConstraint activateConstraints:@[

            [label.centerXAnchor
             constraintEqualToAnchor:
             targetContainer.centerXAnchor]

        ]];
    }


    /*
     ========================================================
     注意：

     这里故意不再切换：

         cowbellCollapsedTopConstraint
         cowbellExpandedTopConstraint

     位置切换全部交给：

         willTransitionToExpandedContentMode:

     这样可以避免收起时发生跳动。
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
                一级 <-> 二级菜单位置切换
 ============================================================

 这是现在唯一负责切换位置的地方。

 不让 viewDidLayoutSubviews 再插手。

 所以：

 一级 -> 二级
        ↓
 直接切换到二级约束

 二级 -> 一级
        ↓
直接切换回一级约束

 不会再出现：
 “先跳到一个位置”
 “重新 layout”
 “再跳回来”
 的情况。
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
                       记录当前状态
     ========================================================
     */

    self.cowbellIsExpanded = expanded;


    /*
     ========================================================
                       切换位置
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
                       强制立即重新布局
     ========================================================

     这样约束切换后马上生效。
     ========================================================
     */

    [self.cowbellLabel.superview layoutIfNeeded];


    /*
     ========================================================
                       原来的淡入淡出
     ========================================================
     */

    [UIView animateWithDuration:0.25
                     animations:^{

        self.cowbellLabel.alpha =
            expanded ? 0.0 : 1.0;

    }];
}


%end


#pragma clang diagnostic pop