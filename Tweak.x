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

// 一级菜单 / 二级菜单分别记录位置
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
                 Cowbell 位置调节区域
 ============================================================

 只需要修改下面两个数字。

 ------------------------------------------------------------
 一级菜单
 ------------------------------------------------------------

 数字越大：
    百分比越往下

 数字越小：
    百分比越往上

 ------------------------------------------------------------
 二级菜单
 ------------------------------------------------------------

 数字越大：
    百分比越往下

 数字越小：
    百分比越往上

 ============================================================
 */

// 一级菜单百分比位置
static CGFloat const COWBELL_COLLAPSED_OFFSET = 8.0;

// 二级菜单百分比位置
static CGFloat const COWBELL_EXPANDED_OFFSET = 20.0;


/*
 ============================================================
                    更新百分比
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

    // 1. 读取电量
    float level = [[UIDevice currentDevice] batteryLevel];

    float safeLevel = (level < 0) ? 1.0 : level;

    int battery = (int)round(safeLevel * 100);

    self.cowbellLabel.text =
        [NSString stringWithFormat:@"%i%%", battery];


    // 2. 低电量模式状态
    BOOL isLPMOn =
        [[NSProcessInfo processInfo] isLowPowerModeEnabled];


    // 3. 保持原来的颜色逻辑
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
    }
}


/*
 ============================================================
                 一级 / 二级菜单布局
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
     ----------------------------------------------------------
     第一次创建 Cowbell 百分比
     ----------------------------------------------------------
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
         ------------------------------------------------------
         保持 Cowbell 原来的镂空效果
         ------------------------------------------------------
         */

        CAFilter *filter =
            [CAFilter filterWithType:kCAFilterDestOut];


        label.layer.filters =
            @[filter];


        /*
         ------------------------------------------------------
         AutoLayout
         ------------------------------------------------------
         */

        label.translatesAutoresizingMaskIntoConstraints = NO;


        [targetContainer addSubview:label];


        self.cowbellLabel = label;


        /*
         ======================================================
                    创建两个独立的位置约束
         ======================================================

         注意：

         这里不是创建两个 Label。

         仍然只有一个 cowbellLabel。

         只是给同一个 Label 准备：

             一级菜单位置
             ↓
             cowbellCollapsedTopConstraint

             二级菜单位置
             ↓
             cowbellExpandedTopConstraint

         所以不会出现：
         “二级菜单重新创建百分比”
         “一级菜单等待二级菜单”
         这种情况。
         ======================================================
         */


        self.cowbellCollapsedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:targetContainer.centerYAnchor
             constant:COWBELL_COLLAPSED_OFFSET];


        self.cowbellExpandedTopConstraint =
            [label.topAnchor
             constraintEqualToAnchor:targetContainer.centerYAnchor
             constant:COWBELL_EXPANDED_OFFSET];


        /*
         ------------------------------------------------------
         两个约束不能同时 Active
         ------------------------------------------------------
         */

        self.cowbellCollapsedTopConstraint.active = YES;

        self.cowbellExpandedTopConstraint.active = NO;


        /*
         ------------------------------------------------------
         水平位置始终保持居中
         ------------------------------------------------------
         */

        [NSLayoutConstraint activateConstraints:@[

            [label.centerXAnchor
             constraintEqualToAnchor:targetContainer.centerXAnchor]

        ]];
    }


    /*
     ==========================================================
                   根据当前状态切换位置
     ==========================================================

     expanded 模式：

         二级菜单位置

     collapsed 模式：

         一级菜单位置
     ==========================================================
     */


    BOOL expanded = NO;


    /*
     这里通过当前 ViewController 的展开状态
     来决定使用哪一套位置。
     */

    if ([self respondsToSelector:
         @selector(isExpanded)]) {

        @try {

            expanded =
                [[self valueForKey:@"expanded"] boolValue];

        } @catch (__unused NSException *exception) {

            expanded = NO;
        }
    }


    /*
     ----------------------------------------------------------
     切换约束
     ----------------------------------------------------------
     */

    if (expanded) {

        self.cowbellCollapsedTopConstraint.active = NO;

        self.cowbellExpandedTopConstraint.active = YES;

    } else {

        self.cowbellExpandedTopConstraint.active = NO;

        self.cowbellCollapsedTopConstraint.active = YES;
    }


    /*
     ----------------------------------------------------------
     保持原来的刷新逻辑
     ----------------------------------------------------------
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
         ------------------------------------------------------
         清理旧 Observer
         ------------------------------------------------------
         */

        [nc removeObserver:self
                      name:NSProcessInfoPowerStateDidChangeNotification
                    object:nil];


        [nc removeObserver:self
                      name:UIDeviceBatteryLevelDidChangeNotification
                    object:nil];


        /*
         ------------------------------------------------------
         低电量模式状态变化
         ------------------------------------------------------
         */

        [nc addObserver:self
               selector:@selector(updateCowbellState)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];


        /*
         ------------------------------------------------------
         电量变化
         ------------------------------------------------------
         */

        [nc addObserver:self
               selector:@selector(updateCowbellState)
                   name:UIDeviceBatteryLevelDidChangeNotification
                 object:nil];


        /*
         ------------------------------------------------------
         立即刷新
         ------------------------------------------------------
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
                展开 / 收起动画
 ============================================================
 */

- (void)willTransitionToExpandedContentMode:(BOOL)expanded {

    %orig(expanded);


    if ([self.moduleIdentifier
         isEqualToString:@"com.apple.control-center.LowPowerModule"]) {


        if (!self.cowbellLabel) return;


        /*
         ------------------------------------------------------
         切换一级 / 二级位置
         ------------------------------------------------------
         */

        self.cowbellCollapsedTopConstraint.active = !expanded;

        self.cowbellExpandedTopConstraint.active = expanded;


        /*
         ------------------------------------------------------
         保持原来的淡入淡出逻辑
         ------------------------------------------------------
         */

        [UIView animateWithDuration:0.25
                         animations:^{

            self.cowbellLabel.alpha =
                expanded ? 0.0 : 1.0;

        }];
    }
}


%end


#pragma clang diagnostic pop