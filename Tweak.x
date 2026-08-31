#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

@interface CCUIContentModuleContainerView : UIView
@property (nonatomic, strong) NSString *moduleIdentifier;
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updatePercentText;
- (BOOL)cb_isLowPowerModule;
@end

%hook CCUIContentModuleContainerView

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)layoutSubviews {
    %orig;

    // 1. 非低电量模块直接隐藏并返回
    if (![self cb_isLowPowerModule]) {
        if (self.cbPercentLabel) {
            self.cbPercentLabel.hidden = YES;
        }
        return;
    }

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0 || width > 100 || height > 100) {
        return;
    }

    // 2. 电池图标完全保持原生位置，不动它
    for (UIView *subview in self.subviews) {
        if (subview != self.cbPercentLabel) {
            subview.transform = CGAffineTransformIdentity;
        }
    }

    // 3. 创建百分比
    if (!self.cbPercentLabel) {

        UILabel *lab =
            [[UILabel alloc] initWithFrame:
             CGRectMake(0, height - 22, width, 12)];

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

         DestOut 会把百分比所在位置从下面的内容中
         “挖掉”，形成镂空效果。

         这就是之前 Cowbell 使用的方式。
         ====================================================
         */

        CAFilter *filter =
            [CAFilter filterWithType:kCAFilterDestOut];

        lab.layer.filters = @[filter];


        self.cbPercentLabel = lab;

        [self addSubview:lab];


        [UIDevice currentDevice].batteryMonitoringEnabled = YES;


        // 电量变化
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(cb_updatePercentText)
                   name:UIDeviceBatteryLevelDidChangeNotification
                 object:nil];


        // 低电量模式变化
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(cb_updatePercentText)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];

    } else {

        self.cbPercentLabel.hidden = NO;

        self.cbPercentLabel.frame =
            CGRectMake(0, height - 22, width, 12);
    }


    // 保证百分比在最上层
    [self bringSubviewToFront:self.cbPercentLabel];


    // 刷新电量
    [self cb_updatePercentText];
}


%new
- (BOOL)cb_isLowPowerModule {

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

        responder = [responder nextResponder];
    }

    return NO;
}


%new
- (void)cb_updatePercentText {

    dispatch_async(dispatch_get_main_queue(), ^{

        if (!self.cbPercentLabel) {
            return;
        }


        /*
         ====================================================
                     获取当前电量
         ====================================================
         */

        float level =
            [UIDevice currentDevice].batteryLevel;


        int percent =
            (level >= 0)
            ? (int)round(level * 100.0f)
            : 100;


        self.cbPercentLabel.text =
            [NSString stringWithFormat:@"%d%%", percent];


        /*
         ====================================================
                     颜色逻辑保持原样
         ====================================================
         */

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

%end

#pragma clang diagnostic pop