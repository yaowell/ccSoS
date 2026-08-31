#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kIsLowPowerKey;


/*
 * ============================================================
 * Control Center
 * ============================================================
 */

@interface SBControlCenterController : UIViewController

- (void)presentAnimated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated;

@end


/*
 * ============================================================
 * CCUICAPackageView
 * ============================================================
 */

@interface CCUICAPackageView : UIView

@property (nonatomic, copy) NSString *packageName;

@end


/*
 * ============================================================
 * Custom Battery View
 * ============================================================
 */

@interface CBCustomBatteryView : UIView

@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UILabel *percentLabel;

@property (nonatomic, assign) float capturedLevel;
@property (nonatomic, assign) int capturedPercent;
@property (nonatomic, assign) BOOL hasCapturedBattery;

@property (nonatomic, assign) BOOL currentLowPowerState;

@end


@implementation CBCustomBatteryView


- (instancetype)initWithFrame:(CGRect)frame {

    if (self = [super initWithFrame:frame]) {

        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;


        /*
         * 初始状态
         */
        self.capturedLevel = 1.0f;
        self.capturedPercent = 100;
        self.hasCapturedBattery = NO;


        /*
         * 当前低电量模式状态
         */
        self.currentLowPowerState =
            [NSProcessInfo processInfo].isLowPowerModeEnabled;


        /*
         * 电池填充
         */
        _fillView = [[UIView alloc] init];

        _fillView.clipsToBounds = YES;

        [self addSubview:_fillView];


        /*
         * 百分比文字
         */
        _percentLabel = [[UILabel alloc] init];

        _percentLabel.textAlignment =
            NSTextAlignmentCenter;

        [self addSubview:_percentLabel];


        /*
         * 开启电池监控。
         *
         * 注意：
         * 不监听电量变化。
         */
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;


        /*
         * 低电量模式变化。
         *
         * 这个必须保留。
         *
         * 点击低电量模块以后，
         * 黄色/白色仍然立即变化。
         */
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(lowPowerModeDidChange:)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];


        /*
         * Control Center 即将打开
         */
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(controlCenterWillPresent:)
                   name:@"CBCustomBatteryControlCenterWillPresent"
                 object:nil];


        /*
         * Control Center 已经关闭
         */
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(controlCenterDidDismiss:)
                   name:@"CBCustomBatteryControlCenterDidDismiss"
                 object:nil];
    }

    return self;
}


- (void)dealloc {

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


/*
 * ============================================================
 * 捕捉一次电量
 * ============================================================
 */

- (void)captureBatteryDataIfNeeded {

    /*
     * 已经捕捉过：
     * 不再读取。
     */
    if (self.hasCapturedBattery) {
        return;
    }


    UIDevice *device =
        [UIDevice currentDevice];


    if (!device.isBatteryMonitoringEnabled) {

        device.batteryMonitoringEnabled =
            YES;
    }


    float level =
        device.batteryLevel;


    /*
     * 如果系统暂时返回无效值，
     * 保持原来的处理方式。
     */
    if (level < 0.0f) {

        level = 1.0f;
    }


    self.capturedLevel =
        level;


    self.capturedPercent =
        (int)round(level * 100.0f);


    self.hasCapturedBattery =
        YES;
}


/*
 * ============================================================
 * Control Center 打开
 * ============================================================
 */

- (void)controlCenterWillPresent:(NSNotification *)notification {

    /*
     * 新的一次 Control Center。
     *
     * 允许重新捕捉一次电量。
     */
    self.hasCapturedBattery = NO;
}


/*
 * ============================================================
 * Control Center 关闭
 * ============================================================
 */

- (void)controlCenterDidDismiss:(NSNotification *)notification {

    /*
     * 本次 Control Center 结束。
     *
     * 清除缓存。
     *
     * 不在这里读取电量。
     */
    self.hasCapturedBattery = NO;
}


/*
 * ============================================================
 * 低电量模式变化
 * ============================================================
 */

- (void)lowPowerModeDidChange:(NSNotification *)notification {

    /*
     * 只更新低电量状态。
     *
     * 不重新读取 batteryLevel。
     */
    self.currentLowPowerState =
        [NSProcessInfo processInfo].isLowPowerModeEnabled;


    dispatch_async(dispatch_get_main_queue(), ^{

        [self setNeedsLayout];

        [self setNeedsDisplay];

    });
}


/*
 * ============================================================
 * Window
 * ============================================================
 */

- (void)didMoveToWindow {

    [super didMoveToWindow];


    if (self.window) {

        /*
         * 如果这是第一次出现，
         * 捕捉一次当前电量。
         */
        [self captureBatteryDataIfNeeded];


        /*
         * 同步当前低电量状态。
         */
        self.currentLowPowerState =
            [NSProcessInfo processInfo].isLowPowerModeEnabled;

    } else {

        /*
         * 真正离开 Window。
         *
         * 清除本次缓存。
         */
        self.hasCapturedBattery = NO;
    }
}


/*
 * ============================================================
 * Geometry
 * ============================================================
 */

- (void)calculateGeometryWithBounds:(CGRect)bounds
                         iconScale:(CGFloat *)outScale
                          iconRect:(CGRect *)outIconRect {

    CGFloat w =
        bounds.size.width;

    CGFloat h =
        bounds.size.height;


    CGFloat scaleH =
        h / 72.0f;

    CGFloat scaleW =
        w / 64.0f;


    CGFloat scale =
        MIN(scaleH, scaleW);


    CGFloat totalW =
        32.0f * scale;


    CGFloat iconH =
        14.0f * scale;


    CGFloat iconX =
        (w - totalW) / 2.0f;


    CGFloat iconY =
        (h - iconH) / 2.0f
        - (1.0f * scale);


    if (outScale) {

        *outScale =
            scale;
    }


    if (outIconRect) {

        *outIconRect =
            CGRectMake(
                iconX,
                iconY,
                totalW,
                iconH
            );
    }
}


/*
 * ============================================================
 * Layout
 * ============================================================
 */

- (void)layoutSubviews {

    [super layoutSubviews];


    CGFloat w =
        self.bounds.size.width;

    CGFloat h =
        self.bounds.size.height;


    if (w <= 0 || h <= 0) {

        return;
    }


    /*
     * 只有没有缓存时才读取电量。
     *
     * 因此：
     *
     * layout 多次
     * ↓
     * 不会重复读取电量
     */
    [self captureBatteryDataIfNeeded];


    CGFloat level =
        self.capturedLevel;


    int currentPercent =
        self.capturedPercent;


    BOOL isLowPower =
        self.currentLowPowerState;


    /*
     * 百分比
     */
    self.percentLabel.text =
        [NSString stringWithFormat:
            @"%d%%",
            currentPercent];


    /*
     * 颜色
     */
    UIColor *themeColor =
        isLowPower
        ?
        [UIColor colorWithRed:1.0
                        green:0.8
                         blue:0.0
                        alpha:1.0]
        :
        [UIColor whiteColor];


    self.percentLabel.textColor =
        isLowPower
        ?
        [UIColor blackColor]
        :
        [UIColor whiteColor];


    self.fillView.backgroundColor =
        themeColor;


    /*
     * Geometry
     */
    CGFloat iconScale = 0;

    CGRect iconRect =
        CGRectZero;


    [self calculateGeometryWithBounds:self.bounds
                           iconScale:&iconScale
                            iconRect:&iconRect];


    CGFloat bodyW =
        iconRect.size.width
        - (3.3f * iconScale);


    CGFloat padding =
        2.0f * iconScale;


    CGFloat currentFillW =
        (bodyW - padding * 2.0f)
        * level;


    CGFloat minFillW =
        2.0f * iconScale;


    if (currentFillW < minFillW) {

        currentFillW =
            minFillW;
    }


    self.fillView.frame =
        CGRectMake(
            iconRect.origin.x + padding,
            iconRect.origin.y + padding,
            currentFillW,
            iconRect.size.height
                - padding * 2.0f
        );


    self.fillView.layer.cornerRadius =
        2.0f * iconScale;


    /*
     * 百分比字体
     */
    self.percentLabel.font =
        [UIFont systemFontOfSize:
            9.3f * iconScale
            weight:UIFontWeightRegular];


    self.percentLabel.frame =
        CGRectMake(
            0,
            iconRect.origin.y
                + iconRect.size.height
                + (5.5f * iconScale),
            w,
            11.0f * iconScale
        );
}


/*
 * ============================================================
 * Draw
 * ============================================================
 */

- (void)drawRect:(CGRect)rect {

    [super drawRect:rect];


    CGFloat w =
        self.bounds.size.width;

    CGFloat h =
        self.bounds.size.height;


    if (w <= 0 || h <= 0) {

        return;
    }


    CGFloat iconScale = 0;

    CGRect iconRect =
        CGRectZero;


    [self calculateGeometryWithBounds:self.bounds
                           iconScale:&iconScale
                            iconRect:&iconRect];


    BOOL isLowPower =
        self.currentLowPowerState;


    UIColor *strokeColor =
        isLowPower
        ?
        [UIColor blackColor]
        :
        [UIColor whiteColor];


    CGFloat bodyW =
        iconRect.size.width
        - (3.3f * iconScale);


    CGFloat lineWidth =
        1.4f * iconScale;


    CGFloat radius =
        4.2f * iconScale;


    /*
     * 电池主体
     */
    UIBezierPath *bodyPath =
        [UIBezierPath
            bezierPathWithRoundedRect:
                CGRectMake(
                    iconRect.origin.x,
                    iconRect.origin.y,
                    bodyW,
                    iconRect.size.height
                )
            cornerRadius:radius];


    bodyPath.lineWidth =
        lineWidth;


    [strokeColor setStroke];

    [bodyPath stroke];


    /*
     * 电池正极
     */
    CGFloat capW =
        1.8f * iconScale;


    CGFloat capH =
        4.8f * iconScale;


    CGFloat capX =
        iconRect.origin.x
        + bodyW
        + (1.5f * iconScale);


    CGFloat capY =
        iconRect.origin.y
        + (iconRect.size.height - capH)
        / 2.0f;


    CGFloat capRadius =
        1.2f * iconScale;


    UIBezierPath *capPath =
        [UIBezierPath
            bezierPathWithRoundedRect:
                CGRectMake(
                    capX,
                    capY,
                    capW,
                    capH
                )
            byRoundingCorners:
                (UIRectCornerTopRight |
                 UIRectCornerBottomRight)
            cornerRadii:
                CGSizeMake(
                    capRadius,
                    capRadius
                )];


    [strokeColor setFill];

    [capPath fill];
}

@end


/*
 * ============================================================
 * CCUICAPackageView
 * ============================================================
 */

%hook CCUICAPackageView

- (void)layoutSubviews {

    %orig;


    NSNumber *isLowPowerTarget =
        objc_getAssociatedObject(
            self,
            &kIsLowPowerKey
        );


    /*
     * 第一次遇到这个 View：
     * 判断是不是低电量模块。
     */
    if (!isLowPowerTarget) {

        NSString *pkgName =
            [self respondsToSelector:
                @selector(packageName)]
            ?
            self.packageName
            :
            @"";


        BOOL matched =
            [pkgName containsString:@"LowPower"]
            ||
            [pkgName containsString:@"Battery"];


        /*
         * 如果 packageName 没有识别出来，
         * 再沿 responder 链寻找 LowPower。
         */
        if (!matched) {

            for (UIResponder *r = self;
                 r;
                 r = r.nextResponder) {

                NSString *cls =
                    NSStringFromClass([r class]);


                if ([cls containsString:@"Brightness"]
                    ||
                    [cls containsString:@"Display"]) {

                    break;
                }


                if ([cls containsString:@"LowPower"]) {

                    matched = YES;

                    break;
                }
            }
        }


        isLowPowerTarget =
            @(matched);


        objc_setAssociatedObject(
            self,
            &kIsLowPowerKey,
            isLowPowerTarget,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }


    /*
     * 不是低电量模块：
     * 完全不处理。
     */
    if (!isLowPowerTarget.boolValue) {

        return;
    }


    /*
     * 隐藏系统原来的内容。
     */
    for (UIView *subview in self.subviews) {

        if (subview.tag != 9999) {

            subview.hidden = YES;
        }
    }


    self.backgroundColor =
        [UIColor clearColor];


    /*
     * 找我们的电池 View。
     */
    CBCustomBatteryView *batteryView =
        [self viewWithTag:9999];


    /*
     * 第一次创建。
     */
    if (!batteryView) {

        batteryView =
            [[CBCustomBatteryView alloc]
                initWithFrame:self.bounds];


        batteryView.tag =
            9999;


        [self addSubview:batteryView];
    }


    /*
     * 每次布局只更新尺寸。
     *
     * 不会因此重新读取电量，
     * 因为 CBCustomBatteryView
     * 内部有 hasCapturedBattery。
     */
    batteryView.frame =
        self.bounds;


    batteryView.hidden =
        NO;


    batteryView.alpha =
        1.0f;
}

%end


/*
 * ============================================================
 * SBControlCenterController
 * ============================================================
 */

%hook SBControlCenterController


/*
 * Control Center 打开
 */

- (void)presentAnimated:(BOOL)animated {

    /*
     * 通知电池 View：
     *
     * 这是新的一次 Control Center。
     *
     * 下一次 layout 时重新捕捉电量。
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            @"CBCustomBatteryControlCenterWillPresent"
                      object:nil];


    %orig(animated);
}


/*
 * Control Center 关闭
 */

- (void)dismissAnimated:(BOOL)animated {

    /*
     * 通知电池 View：
     *
     * 本次 Control Center 结束。
     *
     * 清除缓存，但不读取电量。
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            @"CBCustomBatteryControlCenterDidDismiss"
                      object:nil];


    %orig(animated);
}

%end