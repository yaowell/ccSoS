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

        self.capturedLevel = 1.0f;
        self.capturedPercent = 100;
        self.hasCapturedBattery = NO;

        self.currentLowPowerState =
            [NSProcessInfo processInfo].isLowPowerModeEnabled;


        _fillView = [[UIView alloc] init];
        _fillView.clipsToBounds = YES;
        [self addSubview:_fillView];


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
         * 只监听低电量模式。
         *
         * 用于点击低电量模块后立即改变颜色。
         */
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(lowPowerModeDidChange:)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];


        /*
         * Control Center 打开
         */
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(controlCenterWillPresent:)
                   name:@"CBCustomBatteryControlCenterWillPresent"
                 object:nil];


        /*
         * Control Center 关闭
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
 * 捕捉当前电量
 * ============================================================
 */

- (void)captureBatteryDataIfNeeded {

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
 *
 * 关键：
 * 这里不只是清缓存。
 *
 * 而是立即重新读取一次。
 * ============================================================
 */

- (void)controlCenterWillPresent:(NSNotification *)notification {

    /*
     * 新的一次 Control Center。
     */
    self.hasCapturedBattery = NO;


    /*
     * 立即捕捉。
     *
     * 不 dispatch_async。
     * 不等待点击。
     * 不等待下一次 layout。
     */
    [self captureBatteryDataIfNeeded];


    /*
     * 同步当前低电量状态。
     */
    self.currentLowPowerState =
        [NSProcessInfo processInfo].isLowPowerModeEnabled;


    /*
     * 立即要求显示新数据。
     */
    [self setNeedsLayout];
    [self setNeedsDisplay];
}


/*
 * ============================================================
 * Control Center 关闭
 * ============================================================
 */

- (void)controlCenterDidDismiss:(NSNotification *)notification {

    /*
     * 关闭以后只清缓存。
     *
     * 不读取电量。
     */
    self.hasCapturedBattery = NO;
}


/*
 * ============================================================
 * 低电量模式变化
 *
 * 非常重要：
 *
 * 这里绝对不碰 capturedLevel。
 * 所以点击低电量不会刷新电量。
 * ============================================================
 */

- (void)lowPowerModeDidChange:(NSNotification *)notification {

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
         * 第一次进入 Window 时捕捉。
         */
        [self captureBatteryDataIfNeeded];


        self.currentLowPowerState =
            [NSProcessInfo processInfo].isLowPowerModeEnabled;

    } else {

        /*
         * 离开 Window 时清除。
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

    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;

    CGFloat scaleH = h / 72.0f;
    CGFloat scaleW = w / 64.0f;

    CGFloat scale = MIN(scaleH, scaleW);

    CGFloat totalW = 32.0f * scale;
    CGFloat iconH = 14.0f * scale;

    CGFloat iconX = (w - totalW) / 2.0f;

    CGFloat iconY =
        (h - iconH) / 2.0f
        - (1.0f * scale);


    if (outScale) {
        *outScale = scale;
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
     * 保险机制：
     *
     * 如果没有缓存才读取。
     *
     * 正常情况下这里不会再次读取，
     * 因为 Control Center 打开时已经捕捉过。
     */
    [self captureBatteryDataIfNeeded];


    CGFloat level =
        self.capturedLevel;


    int currentPercent =
        self.capturedPercent;


    BOOL isLowPower =
        self.currentLowPowerState;


    self.percentLabel.text =
        [NSString stringWithFormat:
            @"%d%%",
            currentPercent];


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


    CGFloat iconScale = 0;
    CGRect iconRect = CGRectZero;


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
        currentFillW = minFillW;
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
    CGRect iconRect = CGRectZero;


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


    if (!isLowPowerTarget.boolValue) {
        return;
    }


    for (UIView *subview in self.subviews) {

        if (subview.tag != 9999) {

            subview.hidden = YES;
        }
    }


    self.backgroundColor =
        [UIColor clearColor];


    CBCustomBatteryView *batteryView =
        [self viewWithTag:9999];


    if (!batteryView) {

        batteryView =
            [[CBCustomBatteryView alloc]
                initWithFrame:self.bounds];


        batteryView.tag = 9999;


        [self addSubview:batteryView];
    }


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
 * ============================================================
 * 打开 Control Center
 * ============================================================
 */

- (void)presentAnimated:(BOOL)animated {

    /*
     * 先执行系统原本的 present。
     */
    %orig(animated);


    /*
     * 然后告诉我们的电池 View：
     *
     * 新的一次 Control Center。
     *
     * 立即重新捕捉电量。
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            @"CBCustomBatteryControlCenterWillPresent"
                      object:nil];
}


/*
 * ============================================================
 * 关闭 Control Center
 * ============================================================
 */

- (void)dismissAnimated:(BOOL)animated {

    /*
     * 先让系统正常关闭。
     */
    %orig(animated);


    /*
     * 然后清除本次缓存。
     *
     * 不读取电量。
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            @"CBCustomBatteryControlCenterDidDismiss"
                      object:nil];
}

%end