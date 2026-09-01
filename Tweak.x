#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString *const kCAFilterDestOut;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

#pragma mark - CCUICAPackageView

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

static char kIsLowPowerKey;

#pragma mark - CBCustomBatteryView

@interface CBCustomBatteryView : UIView

@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) CAFilter *destOutFilter;

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

        self.lastPercent = -1;
        self.lastLowPowerState = NO;

        /*
         * 电池内部填充
         */
        _fillView = [[UIView alloc] init];
        _fillView.clipsToBounds = YES;
        _fillView.userInteractionEnabled = NO;
        [self addSubview:_fillView];

        /*
         * 百分比
         *
         * 使用 DestOut：
         * 文字所在位置变成透明，
         * 从而露出下面的电池填充颜色，
         * 达到 Cowbell 的镂空效果。
         */
        _percentLabel = [[UILabel alloc] init];
        _percentLabel.textAlignment = NSTextAlignmentCenter;
        _percentLabel.backgroundColor = [UIColor clearColor];
        _percentLabel.userInteractionEnabled = NO;
        [self addSubview:_percentLabel];

        /*
         * CAFilter 只创建一次。
         *
         * 不要在每次电量变化的时候重新创建。
         */
        _destOutFilter = [CAFilter filterWithType:kCAFilterDestOut];

        if (_destOutFilter) {
            _percentLabel.layer.filters = @[_destOutFilter];
        }

        /*
         * 开启电池监控。
         */
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }

    return self;
}

#pragma mark - Window 生命周期

- (void)didMoveToWindow {
    [super didMoveToWindow];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    if (self.window) {

        if (![UIDevice currentDevice].isBatteryMonitoringEnabled) {
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        }

        /*
         * 只监听真正需要的两个通知：
         *
         * 1. 电量变化
         * 2. 低电量模式变化
         *
         * 不再监听 BatteryStateDidChange。
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
         * View 进入窗口时主动同步一次。
         */
        [self updateBatteryData];

    } else {

        /*
         * 离开窗口立即停止监听。
         */
        [nc removeObserver:self];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 电量更新

- (void)updateBatteryData {

    if (!self.window) {
        return;
    }

    /*
     * UI 更新统一放到主线程。
     * 保留这一层，不为了极小的调度开销去改变
     * 当前已经稳定的刷新逻辑。
     */
    dispatch_async(dispatch_get_main_queue(), ^{

        if (!self.window) {
            return;
        }

        if (![UIDevice currentDevice].isBatteryMonitoringEnabled) {
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        }

        float level = [UIDevice currentDevice].batteryLevel;

        if (level < 0.0f) {
            level = 1.0f;
        }

        int currentPercent = (int)round(level * 100.0f);

        BOOL currentLowPower =
            [NSProcessInfo processInfo].isLowPowerModeEnabled;

        /*
         * 核心省电逻辑：
         *
         * 电量和低电量状态都没有变化，
         * 什么 UI 工作都不做。
         */
        if (currentPercent == self.lastPercent &&
            currentLowPower == self.lastLowPowerState) {
            return;
        }

        self.lastPercent = currentPercent;
        self.lastLowPowerState = currentLowPower;

        /*
         * 更新文字。
         */
        self.percentLabel.text =
            [NSString stringWithFormat:@"%d%%", currentPercent];

        /*
         * Cowbell 风格：
         *
         * 普通模式：白色
         * 低电量模式：黄色填充
         *
         * 百分比本身通过 DestOut 镂空。
         */
        UIColor *fillColor;

        if (currentLowPower) {
            fillColor =
                [UIColor colorWithRed:1.0f
                                green:0.8f
                                 blue:0.0f
                                alpha:1.0f];
        } else {
            fillColor = [UIColor whiteColor];
        }

        self.fillView.backgroundColor = fillColor;

        /*
         * DestOut 需要文字本身有不透明内容，
         * 这样文字区域才能形成透明镂空。
         */
        self.percentLabel.textColor = [UIColor whiteColor];

        /*
         * 只在真正发生状态变化的时候重新绘制。
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
            CGRectMake(iconX,
                       iconY,
                       totalW,
                       iconH);
    }
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    if (w <= 0.0f || h <= 0.0f) {
        return;
    }

    if (![UIDevice currentDevice].isBatteryMonitoringEnabled) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }

    float level = [UIDevice currentDevice].batteryLevel;

    if (level < 0.0f) {
        level = 1.0f;
    }

    /*
     * 这里仍然同步缓存状态，
     * 但是不在 layoutSubviews 里面反复 setNeedsDisplay。
     *
     * 这样可以避免 layout → update → layout 的循环。
     */
    int currentPercent =
        (int)round(level * 100.0f);

    BOOL isLowPower =
        [NSProcessInfo processInfo].isLowPowerModeEnabled;

    self.lastPercent = currentPercent;
    self.lastLowPowerState = isLowPower;

    self.percentLabel.text =
        [NSString stringWithFormat:@"%d%%", currentPercent];

    UIColor *themeColor =
        isLowPower
        ? [UIColor colorWithRed:1.0f
                          green:0.8f
                           blue:0.0f
                          alpha:1.0f]
        : [UIColor whiteColor];

    self.fillView.backgroundColor = themeColor;

    /*
     * 计算电池图标位置。
     */
    CGFloat iconScale = 0.0f;
    CGRect iconRect = CGRectZero;

    [self calculateGeometryWithBounds:self.bounds
                           iconScale:&iconScale
                            iconRect:&iconRect];

    /*
     * 电池主体宽度。
     */
    CGFloat bodyW =
        iconRect.size.width
        - (3.3f * iconScale);

    CGFloat padding =
        2.0f * iconScale;

    /*
     * 当前电量对应的填充宽度。
     */
    CGFloat currentFillW =
        (bodyW - padding * 2.0f)
        * level;

    /*
     * 保留最小可见填充。
     */
    CGFloat minFillW =
        2.0f * iconScale;

    if (currentFillW < minFillW) {
        currentFillW = minFillW;
    }

    self.fillView.frame =
        CGRectMake(iconRect.origin.x + padding,
                   iconRect.origin.y + padding,
                   currentFillW,
                   iconRect.size.height
                       - padding * 2.0f);

    self.fillView.layer.cornerRadius =
        2.0f * iconScale;

    /*
     * 百分比位置。
     *
     * 放在电池主体里面，
     * DestOut 后就会看到下面的填充颜色。
     */
    self.percentLabel.font =
        [UIFont systemFontOfSize:
                    9.3f * iconScale
                          weight:UIFontWeightRegular];

    self.percentLabel.frame =
        CGRectMake(iconRect.origin.x,
                   iconRect.origin.y,
                   bodyW,
                   iconRect.size.height);

    /*
     * 确保 Filter 仍然只使用初始化时创建的那个。
     *
     * 不重新创建。
     */
    if (self.destOutFilter &&
        self.percentLabel.layer.filters.firstObject
            != self.destOutFilter) {

        self.percentLabel.layer.filters =
            @[self.destOutFilter];
    }
}

#pragma mark - 手绘电池图标

- (void)drawRect:(CGRect)rect {

    [super drawRect:rect];

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

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

    UIColor *strokeColor =
        isLowPower
        ? [UIColor blackColor]
        : [UIColor whiteColor];

    /*
     * 电池主体。
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

    bodyPath.lineWidth = lineWidth;

    [strokeColor setStroke];

    [bodyPath stroke];

    /*
     * 电池正极。
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
        + (iconRect.size.height - capH) / 2.0f;

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
     * 第一次遇到这个 PackageView 时，
     * 判断它是不是低电量模块。
     *
     * 判断结果缓存下来，避免每次 layout 都遍历 responder。
     */
    NSNumber *isLowPowerTarget =
        objc_getAssociatedObject(self,
                                 &kIsLowPowerKey);

    if (!isLowPowerTarget) {

        NSString *pkgName = @"";

        if ([self respondsToSelector:@selector(packageName)]) {
            pkgName = self.packageName ?: @"";
        }

        BOOL matched =
            [pkgName containsString:@"LowPower"] ||
            [pkgName containsString:@"Battery"];

        if (!matched) {

            for (UIResponder *r = self;
                 r;
                 r = r.nextResponder) {

                NSString *cls =
                    NSStringFromClass([r class]);

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

        isLowPowerTarget = @(matched);

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
     * 隐藏系统原来的电池图标。
     *
     * 只保留我们自己的 9999 View。
     */
    for (UIView *subview in self.subviews) {

        if (subview.tag != 9999) {
            subview.hidden = YES;
        }
    }

    self.backgroundColor =
        [UIColor clearColor];

    /*
     * 查找/创建自定义电池 View。
     */
    CBCustomBatteryView *batteryView =
        (CBCustomBatteryView *)
            [self viewWithTag:9999];

    if (!batteryView) {

        batteryView =
            [[CBCustomBatteryView alloc]
                initWithFrame:self.bounds];

        batteryView.tag = 9999;

        [self addSubview:batteryView];
    }

    /*
     * 保持尺寸同步。
     */
    batteryView.frame =
        self.bounds;

    batteryView.hidden = NO;
    batteryView.alpha = 1.0f;
}

%end

#pragma clang diagnostic pop