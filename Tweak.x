#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char kIsLowPowerKey;
static char kCustomBatteryViewKey;

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

@interface CBCustomBatteryView : UIView
@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) CAShapeLayer *bodyLayer;
@property (nonatomic, strong) CAShapeLayer *capLayer;
@property (nonatomic, assign) int lastPercent;
@property (nonatomic, assign) BOOL lastLowPowerState;
- (void)updateBatteryData;
@end

@implementation CBCustomBatteryView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.lastPercent = -1;
        self.lastLowPowerState = NO;

        // 1. 矢量外框 (使用 CAShapeLayer，走 GPU 矢量渲染，零 CPU 绘制消耗)
        _bodyLayer = [CAShapeLayer layer];
        _bodyLayer.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:_bodyLayer];

        _capLayer = [CAShapeLayer layer];
        [self.layer addSublayer:_capLayer];

        // 2. 内部填充条
        _fillView = [[UIView alloc] init];
        _fillView.clipsToBounds = YES;
        [self addSubview:_fillView];

        // 3. 百分比 Label
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
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [nc removeObserver:self];
        [nc addObserver:self selector:@selector(updateBatteryData) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(updateBatteryData) name:UIDeviceBatteryStateDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(updateBatteryData) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [self updateBatteryData];
    } else {
        [nc removeObserver:self];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateBatteryData {
    if (!self.window) return;

    float level = [UIDevice currentDevice].batteryLevel;
    if (level < 0) level = 1.0f;
    int currentPercent = (int)round(level * 100);
    BOOL currentLowPower = [NSProcessInfo processInfo].isLowPowerModeEnabled;

    // 状态未改变时直接跳过，零重复计算
    if (currentPercent == self.lastPercent && currentLowPower == self.lastLowPowerState) {
        return;
    }

    self.lastPercent = currentPercent;
    self.lastLowPowerState = currentLowPower;

    // 直接刷新视图布局
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    if (w <= 0 || h <= 0) return;

    float level = [UIDevice currentDevice].batteryLevel;
    if (level < 0) level = 1.0f;
    int currentPercent = (self.lastPercent >= 0) ? self.lastPercent : (int)round(level * 100);
    BOOL isLowPower = [NSProcessInfo processInfo].isLowPowerModeEnabled;

    // 尺寸比例计算
    CGFloat scale = MIN(h / 72.0f, w / 64.0f);
    CGFloat totalW = 32.0f * scale;
    CGFloat iconH = 14.0f * scale;
    CGFloat iconX = (w - totalW) / 2.0f;
    CGFloat iconY = (h - iconH) / 2.0f - (1.0f * scale);
    CGRect iconRect = CGRectMake(iconX, iconY, totalW, iconH);

    CGFloat bodyW = iconRect.size.width - (3.3f * scale);
    CGFloat padding = 2.0f * scale;

    // 配色方案
    UIColor *themeColor = isLowPower ? [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0] : [UIColor whiteColor];
    UIColor *strokeColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    // 更新 CAShapeLayer 矢量路径（纯内存矢量运算，无需重绘点阵）
    UIBezierPath *bodyPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(iconRect.origin.x, iconRect.origin.y, bodyW, iconRect.size.height) cornerRadius:4.2f * scale];
    self.bodyLayer.path = bodyPath.CGPath;
    self.bodyLayer.strokeColor = strokeColor.CGColor;
    self.bodyLayer.lineWidth = 1.4f * scale;

    CGFloat capW = 1.8f * scale;
    CGFloat capH = 4.8f * scale;
    CGFloat capX = iconRect.origin.x + bodyW + (1.5f * scale);
    CGFloat capY = iconRect.origin.y + (iconRect.size.height - capH) / 2.0f;
    UIBezierPath *capPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(capX, capY, capW, capH)
                                                  byRoundingCorners:(UIRectCornerTopRight | UIRectCornerBottomRight)
                                                        cornerRadii:CGSizeMake(1.2f * scale, 1.2f * scale)];
    self.capLayer.path = capPath.CGPath;
    self.capLayer.fillColor = strokeColor.CGColor;

    // 更新电池电量填充条 Frame
    CGFloat currentFillW = (bodyW - padding * 2.0f) * level;
    CGFloat minFillW = 2.0f * scale;
    if (currentFillW < minFillW) currentFillW = minFillW;
    
    self.fillView.backgroundColor = themeColor;
    self.fillView.frame = CGRectMake(iconRect.origin.x + padding, iconRect.origin.y + padding, currentFillW, iconRect.size.height - padding * 2.0f);
    self.fillView.layer.cornerRadius = 2.0f * scale;

    // 更新百分比 Label
    self.percentLabel.text = [NSString stringWithFormat:@"%d%%", currentPercent];
    self.percentLabel.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];
    self.percentLabel.font = [UIFont systemFontOfSize:9.3f * scale weight:UIFontWeightRegular];
    self.percentLabel.frame = CGRectMake(0, iconRect.origin.y + iconRect.size.height + (5.5f * scale), w, 11.0f * scale);
}

@end

%hook CCUICAPackageView

- (void)layoutSubviews {
    %orig;

    // 1. 使用关联对象记录匹配结果，避免每次 layout 都遍历 Responder 链
    NSNumber *isLowPowerTarget = objc_getAssociatedObject(self, &kIsLowPowerKey);
    if (!isLowPowerTarget) {
        NSString *pkgName = [self respondsToSelector:@selector(packageName)] ? self.packageName : @"";
        BOOL matched = [pkgName containsString:@"LowPower"] || [pkgName containsString:@"Battery"];

        if (!matched) {
            for (UIResponder *r = self; r; r = r.nextResponder) {
                NSString *cls = NSStringFromClass([r class]);
                if ([cls containsString:@"Brightness"] || [cls containsString:@"Display"]) break;
                if ([cls containsString:@"LowPower"]) { matched = YES; break; }
            }
        }
        isLowPowerTarget = @(matched);
        objc_setAssociatedObject(self, &kIsLowPowerKey, isLowPowerTarget, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!isLowPowerTarget.boolValue) return;

    // 2. 只有在首次初始化时将系统子视图隐藏，避免高频遍历 subviews
    CBCustomBatteryView *batteryView = objc_getAssociatedObject(self, &kCustomBatteryViewKey);
    if (!batteryView) {
        for (UIView *subview in self.subviews) {
            subview.hidden = YES;
        }

        self.backgroundColor = [UIColor clearColor];

        batteryView = [[CBCustomBatteryView alloc] initWithFrame:self.bounds];
        [self addSubview:batteryView];
        
        objc_setAssociatedObject(self, &kCustomBatteryViewKey, batteryView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // 3. 仅调整大小，不重复创建与遍历
    batteryView.frame = self.bounds;
}

%end
