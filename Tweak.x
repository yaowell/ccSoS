#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kIsLowPowerKey;

// 1. 完整声明类结构，继承自 UIView，防止 Clang 报 forward declaration 错误
@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

// 2. 自定义电池 View 声明
@interface CBCustomBatteryView : UIView
@property (nonatomic, strong) CAShapeLayer *bodyLayer;
@property (nonatomic, strong) CAShapeLayer *capLayer;
@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UILabel *percentLabel;
- (void)updateBatteryData;
@end

@implementation CBCustomBatteryView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];

        // 外框图层 (GPU 绘制，极省电)
        _bodyLayer = [CAShapeLayer layer];
        _bodyLayer.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:_bodyLayer];

        // 电池头图层
        _capLayer = [CAShapeLayer layer];
        [self.layer addSublayer:_capLayer];

        // 内部填充 View
        _fillView = [[UIView alloc] init];
        _fillView.clipsToBounds = YES;
        [self addSubview:_fillView];

        // 电量百分比标签
        _percentLabel = [[UILabel alloc] init];
        _percentLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_percentLabel];
    }
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if (self.window) {
        // 挂载到窗口时开启系统电量监听并注册通知
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [nc addObserver:self selector:@selector(updateBatteryData) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(updateBatteryData) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [self updateBatteryData];
    } else {
        // 移出窗口时解绑通知
        [nc removeObserver:self];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateBatteryData {
    if (!self.window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    if (w <= 0 || h <= 0) return;

    float level = [UIDevice currentDevice].batteryLevel;
    if (level < 0) level = 1.0f;
    int currentPercent = (int)round(level * 100);
    BOOL isLowPower = [NSProcessInfo processInfo].isLowPowerModeEnabled;

    UIColor *strokeColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];
    UIColor *themeColor = isLowPower ? [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0] : [UIColor whiteColor];

    // 计算 Scale 比例
    CGFloat scale = MIN(h / 72.0f, w / 64.0f);
    CGFloat totalW = 32.0f * scale;
    CGFloat iconH = 14.0f * scale;
    CGRect iconRect = CGRectMake((w - totalW) / 2.0f, (h - iconH) / 2.0f - scale, totalW, iconH);

    // 1. 绘制外框与极头 Path
    CGFloat bodyW = iconRect.size.width - (3.3f * scale);
    _bodyLayer.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(iconRect.origin.x, iconRect.origin.y, bodyW, iconRect.size.height) cornerRadius:4.2f * scale].CGPath;
    _bodyLayer.strokeColor = strokeColor.CGColor;
    _bodyLayer.lineWidth = 1.4f * scale;

    CGFloat capW = 1.8f * scale, capH = 4.8f * scale;
    CGFloat capX = iconRect.origin.x + bodyW + (1.5f * scale);
    CGFloat capY = iconRect.origin.y + (iconRect.size.height - capH) / 2.0f;
    _capLayer.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(capX, capY, capW, capH)
                                           byRoundingCorners:(UIRectCornerTopRight | UIRectCornerBottomRight)
                                                 cornerRadii:CGSizeMake(1.2f * scale, 1.2f * scale)].CGPath;
    _capLayer.fillColor = strokeColor.CGColor;

    // 2. 更新电量填充区域
    CGFloat padding = 2.1f * scale;
    CGFloat currentFillW = MAX((bodyW - padding * 2.0f) * level, 2.0f * scale);
    _fillView.frame = CGRectMake(iconRect.origin.x + padding, iconRect.origin.y + padding, currentFillW, iconRect.size.height - padding * 2.0f);
    _fillView.backgroundColor = themeColor;
    _fillView.layer.cornerRadius = 2.0f * scale;

    // 3. 更新百分比文本
    _percentLabel.text = [NSString stringWithFormat:@"%d%%", currentPercent];
    _percentLabel.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];
    _percentLabel.font = [UIFont systemFontOfSize:9.5f * scale weight:UIFontWeightRegular];
    _percentLabel.frame = CGRectMake(0, iconRect.origin.y + iconRect.size.height + (5.5f * scale), w, 11.0f * scale);
}

@end

// 3. Hook 逻辑入口
%hook CCUICAPackageView

- (void)layoutSubviews {
    %orig;

    // 判定是否为低电量图标（绑定 Associated Object 避免重复判断）
    NSNumber *isLowPowerTarget = objc_getAssociatedObject(self, &kIsLowPowerKey);
    if (!isLowPowerTarget) {
        NSString *pkgName = [self respondsToSelector:@selector(packageName)] ? [self performSelector:@selector(packageName)] : @"";
        BOOL matched = [pkgName containsString:@"LowPower"] || [pkgName containsString:@"Battery"];
        isLowPowerTarget = @(matched);
        objc_setAssociatedObject(self, &kIsLowPowerKey, isLowPowerTarget, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!isLowPowerTarget.boolValue) return;

    // 注入自定义 View
    CBCustomBatteryView *batteryView = (CBCustomBatteryView *)[self viewWithTag:9999];
    if (!batteryView) {
        batteryView = [[CBCustomBatteryView alloc] initWithFrame:self.bounds];
        batteryView.tag = 9999;
        [self addSubview:batteryView];

        // 隐藏低电量按钮原本的系统矢量图层（只在初始化时隐藏一次）
        for (UIView *subview in self.subviews) {
            if (subview != batteryView) {
                subview.hidden = YES;
            }
        }
    }

    batteryView.frame = self.bounds;
}

%end
