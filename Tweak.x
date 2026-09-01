#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

static char kIsLowPowerKey;

#pragma mark - CBCustomBatteryView

@interface CBCustomBatteryView : UIView

@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UILabel *percentLabel;

@property (nonatomic, assign) int lastPercent;
@property (nonatomic, assign) BOOL lastLowPowerState;

- (void)updateBatteryData;

@end

@implementation CBCustomBatteryView

#pragma mark - 初始化

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {

        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;

        /*
         * -1 表示还没有进行过第一次有效记录
         */
        self.lastPercent = -1;
        self.lastLowPowerState = NO;

        /*
         * 电池填充部分
         */
        _fillView = [[UIView alloc] init];
        _fillView.clipsToBounds = YES;
        _fillView.userInteractionEnabled = NO;
        [self addSubview:_fillView];

        /*
         * 百分比
         */
        _percentLabel = [[UILabel alloc] init];
        _percentLabel.textAlignment = NSTextAlignmentCenter;
        _percentLabel.backgroundColor = [UIColor clearColor];
        _percentLabel.userInteractionEnabled = NO;

        [self addSubview:_percentLabel];

        /*
         * 开启电池监控
         */
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }

    return self;
}

#pragma mark - Window 生命周期

- (void)didMoveToWindow {

    [super didMoveToWindow];

    NSNotificationCenter *nc =
        [NSNotificationCenter defaultCenter];

    if (self.window) {

        /*
         * 确保电池监控开启
         */
        if (![UIDevice currentDevice].isBatteryMonitoringEnabled) {
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        }

        /*
         * 只监听两个真正需要的通知：
         *
         * 1. 电量发生变化
         * 2. 低电量模式发生变化
         *
         * 不再监听：
         * UIDeviceBatteryStateDidChangeNotification
         */
        [nc addObserver:self
               selector:@selector(updateBatteryData)
                   name:UIDeviceBatteryLevelDidChangeNotification
                 object:nil];

        [nc addObserver:self
               selector:@selector(updateBatteryData)
                   name:NSProcessInfoPowerStateDidChangeNotification
                 object:nil];

        /*
         * 进入窗口时立即同步一次
         */
        [self updateBatteryData];

    } else {

        /*
         * 离开窗口后停止监听
         */
        [nc removeObserver:self];
    }
}

- (void)dealloc {

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

#pragma mark - 电量更新

- (void)updateBatteryData {

    if (!self.window) {
        return;
    }

    /*
     * UI 操作统一放主线程。
     */
    dispatch_async(dispatch_get_main_queue(), ^{

        if (!self.window) {
            return;
        }

        if (![UIDevice currentDevice].isBatteryMonitoringEnabled) {
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        }

        /*
         * 获取电量
         */
        float level =
            [UIDevice currentDevice].batteryLevel;

        if (level < 0.0f) {
            level = 1.0f;
        }

        int currentPercent =
            (int)round(level * 100.0f);

        /*
         * 获取低电量模式状态
         */
        BOOL currentLowPower =
            [NSProcessInfo processInfo].isLowPowerModeEnabled;

        /*
         * 核心省电逻辑：
         *
         * 电量和低电量状态都没变化，
         * 就完全不进行 UI 刷新。
         */
        if (currentPercent == self.lastPercent &&
            currentLowPower == self.lastLowPowerState) {

            return;
        }

        /*
         * 保存最新状态
         */
        self.lastPercent = currentPercent;
        self.lastLowPowerState = currentLowPower;

        /*
         * 更新百分比
         */
        self.percentLabel.text =
            [NSString stringWithFormat:@"%d%%",
                                       currentPercent];

        /*
         * 普通模式：
         * 白色电池 + 白色字体
         *
         * 低电量模式：
         * 黄色电池 + 黑色字体
         */
        if (currentLowPower) {

            self.fillView.backgroundColor =
                [UIColor colorWithRed:1.0f
                                green:0.8f
                                 blue:0.0f
                                alpha:1.0f];

            self.percentLabel.textColor =
                [UIColor blackColor];

        } else {

            self.fillView.backgroundColor =
                [UIColor whiteColor];

            self.percentLabel.textColor =
                [UIColor whiteColor];
        }

        /*
         * 只有真正发生变化的时候才请求布局和绘制。
         */
        [self setNeedsLayout];
        [self setNeedsDisplay];
    });
}

#pragma mark - 几何计算

- (void)calculateGeometryWithBounds:(CGRect)bounds
                         iconScale:(CGFloat *)outScale
                          iconRect:(CGRect *)outIconRect {

    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;

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
        *outScale = scale;
    }

    if (outIconRect) {
        *outIconRect =
            CGRectMake(iconX,
                       iconY,
                       totalW,
                       iconH);
    }
}

#pragma mark - Layout

- (void)layoutSubviews {

    [super layoutSubviews];

    CGFloat w =
        self.bounds.size.width;

    CGFloat h =
        self.bounds.size.height;

    if (w <= 0.0f || h <= 0.0f) {
        return;
    }

    /*
     * 确保电池监控仍然开启
     */
    if (![UIDevice currentDevice].isBatteryMonitoringEnabled) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }

    /*
     * 获取当前电量
     */
    float level =
        [UIDevice currentDevice].batteryLevel;

    if (level < 0.0f) {
        level = 1.0f;
    }

    int currentPercent =
        (int)round(level * 100.0f);

    BOOL isLowPower =
        [NSProcessInfo processInfo].isLowPowerModeEnabled;

    /*
     * 同步缓存。
     *
     * 注意：
     * 这里不调用 setNeedsLayout，
     * 防止 layout → layout 循环。
     */
    self.lastPercent =
        currentPercent;

    self.lastLowPowerState =
        isLowPower;

    /*
     * 百分比
     */
    self.percentLabel.text =
        [NSString stringWithFormat:@"%d%%",
                                   currentPercent];

    /*
     * 颜色
     */
    if (isLowPower) {

        self.fillView.backgroundColor =
            [UIColor colorWithRed:1.0f
                            green:0.8f
                             blue:0.0f
                            alpha:1.0f];

        self.percentLabel.textColor =
            [UIColor blackColor];

    } else {

        self.fillView.backgroundColor =
            [UIColor whiteColor];

        self.percentLabel.textColor =
            [UIColor whiteColor];
    }

    /*
     * 计算电池图标尺寸
     */
    CGFloat iconScale = 0.0f;
    CGRect iconRect = CGRectZero;

    [self calculateGeometryWithBounds:self.bounds
                           iconScale:&iconScale
                            iconRect:&iconRect];

    /*
     * 电池主体宽度
     */
    CGFloat bodyW =
        iconRect.size.width
        - (3.3f * iconScale);

    CGFloat padding =
        2.0f * iconScale;

    /*
     * 当前电量对应的填充宽度
     */
    CGFloat currentFillW =
        (bodyW - padding * 2.0f)
        * level;

    /*
     * 最小可见宽度
     */
    CGFloat minFillW =
        2.0f * iconScale;

    if (currentFillW < minFillW) {
        currentFillW = minFillW;
    }

    /*
     * 电池填充
     */
    self.fillView.frame =
        CGRectMake(iconRect.origin.x + padding,
                   iconRect.origin.y + padding,
                   currentFillW,
                   iconRect.size.height
                       - padding * 2.0f);

    self.fillView.layer.cornerRadius =
        2.0f * iconScale;

    /*
     * 百分比字体
     */
    self.percentLabel.font =
        [UIFont systemFontOfSize:
                    9.3f * iconScale
                          weight:UIFontWeightRegular];

    /*
     * 百分比放在电池主体内部
     */
    self.percentLabel.frame =
        CGRectMake(iconRect.origin.x,
                   iconRect.origin.y,
                   bodyW,
                   iconRect.size.height);
}

#pragma mark - 手绘电池外框

- (void)drawRect:(CGRect)rect {

    [super drawRect:rect];

    CGFloat w =
        self.bounds.size.width;

    CGFloat h =
        self.bounds.size.height;

    if (w <= 0.0f || h <= 0.0f) {
        return;
    }

    CGFloat iconScale = 0.0f;
    CGRect iconRect = CGRectZero;

    [self calculateGeometryWithBounds:self.bounds
                           iconScale:&iconScale
                            iconRect:&iconRect];

    BOOL isLowPower =
        [NSProcessInfo processInfo].isLowPowerModeEnabled;

    /*
     * 外框颜色：
     *
     * 普通模式 = 白色
     * 低电量模式 = 黑色
     */
    UIColor *strokeColor =
        isLowPower
        ? [UIColor blackColor]
        : [UIColor whiteColor];

    /*
     * 电池主体
     */
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
                CGRectMake(iconRect.origin.x,
                           iconRect.origin.y,
                           bodyW,
                           iconRect.size.height)
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
                CGRectMake(capX,
                           capY,
                           capW,
                           capH)
                    byRoundingCorners:
                        (UIRectCornerTopRight |
                         UIRectCornerBottomRight)
                          cornerRadii:
                              CGSizeMake(capRadius,
                                         capRadius)];

    [strokeColor setFill];

    [capPath fill];
}

@end

#pragma mark - CCUICAPackageView Hook

%hook CCUICAPackageView

- (void)layoutSubviews {

    %orig;

    /*
     * 第一次遇到 PackageView 时判断
     * 是否为低电量模块。
     */
    NSNumber *isLowPowerTarget =
        objc_getAssociatedObject(self,
                                 &kIsLowPowerKey);

    if (!isLowPowerTarget) {

        NSString *pkgName = @"";

        if ([self respondsToSelector:@selector(packageName)]) {
            pkgName =
                self.packageName ?: @"";
        }

        BOOL matched =
            [pkgName containsString:@"LowPower"] ||
            [pkgName containsString:@"Battery"];

        /*
         * 如果 packageName 没匹配，
         * 再通过 responder chain 判断。
         */
        if (!matched) {

            for (UIResponder *r = self;
                 r;
                 r = r.nextResponder) {

                NSString *cls =
                    NSStringFromClass([r class]);

                /*
                 * 避免误匹配亮度/显示模块
                 */
                if ([cls containsString:@"Brightness"] ||
                    [cls containsString:@"Display"]) {

                    break;
                }

                if ([cls containsString:@"LowPower"]) {

                    matched = YES;
                    break;
                }
            }
        }

        /*
         * 缓存判断结果。
         *
         * 后续 layout 不再重复遍历。
         */
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
     * 查找自定义电池 View。
     */
    CBCustomBatteryView *batteryView =
        (CBCustomBatteryView *)
            [self viewWithTag:9999];

    /*
     * 不存在则创建。
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
     * 保持大小与 PackageView 同步。
     */
    batteryView.frame =
        self.bounds;

    batteryView.hidden =
        NO;

    batteryView.alpha =
        1.0f;
}

%end