#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kIsLowPowerKey;

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

@interface CBCustomBatteryView : UIView
@property (nonatomic, strong) CAShapeLayer *bodyLayer;
@property (nonatomic, strong) CAShapeLayer *capLayer;
@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, assign) CGRect lastBounds;
@property (nonatomic, assign) float capturedLevel;
@property (nonatomic, assign) int capturedPercent;
@property (nonatomic, assign) BOOL hasSnapshot;
- (void)updateColorsOnly;
- (void)resetSnapshot;
@end

@implementation CBCustomBatteryView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.lastBounds = CGRectZero;
        self.capturedLevel = -1;
        self.capturedPercent = -1;
        self.hasSnapshot = NO;

        _bodyLayer = [CAShapeLayer layer];
        _bodyLayer.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:_bodyLayer];

        _capLayer = [CAShapeLayer layer];
        [self.layer addSublayer:_capLayer];

        _fillView = [[UIView alloc] init];
        _fillView.clipsToBounds = YES;
        [self addSubview:_fillView];

        _percentLabel = [[UILabel alloc] init];
        _percentLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_percentLabel];
    }
    return self;
}

- (void)resetSnapshot {
    self.hasSnapshot = NO;
    self.lastBounds = CGRectZero;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if (self.window) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [nc addObserver:self selector:@selector(updateColorsOnly) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    } else {
        [nc removeObserver:self];
        [self resetSnapshot];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateColorsOnly {
    if (!self.window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.lastBounds = CGRectZero;
        [self setNeedsLayout];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    if (w <= 0 || h <= 0) return;

    if (!self.hasSnapshot) {
        float lv = [UIDevice currentDevice].batteryLevel;
        if(lv < 0) lv = 1.0f;
        self.capturedLevel = lv;
        self.capturedPercent = (int)round(lv * 100);
        self.hasSnapshot = YES;
    }

    if (CGRectEqualToRect(self.bounds, self.lastBounds)) {
        return;
    }
    self.lastBounds = self.bounds;

    float level = self.capturedLevel;
    int currentPercent = self.capturedPercent;
    BOOL isLowPower = [NSProcessInfo processInfo].isLowPowerModeEnabled;

    UIColor *strokeColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];
    UIColor *themeColor = isLowPower ? [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0] : [UIColor whiteColor];

    CGFloat scale = MIN(h / 72.0f, w / 64.0f);
    CGFloat totalW = 32.0f * scale;
    CGFloat iconH = 14.0f * scale;
    CGRect iconRect = CGRectMake((w - totalW) / 2.0f, (h - iconH) / 2.0f - scale, totalW, iconH);

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

    CGFloat padding = 2.1f * scale;
    CGFloat currentFillW = MAX((bodyW - padding * 2.0f) * level, 2.0f * scale);
    _fillView.frame = CGRectMake(iconRect.origin.x + padding, iconRect.origin.y + padding, currentFillW, iconRect.size.height - padding * 2.0f);
    _fillView.backgroundColor = themeColor;
    _fillView.layer.cornerRadius = 2.0f * scale;

    _percentLabel.text = [NSString stringWithFormat:@"%d%%", currentPercent];
    _percentLabel.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];
    _percentLabel.font = [UIFont systemFontOfSize:9.5f * scale weight:UIFontWeightBold];
    _percentLabel.frame = CGRectMake(0, iconRect.origin.y + iconRect.size.height + (3.0f * scale), w, 12.0f * scale);
}

@end

%hook CCUICAPackageView

- (void)setHidden:(BOOL)hidden {
    %orig;
    if (hidden) {
        CBCustomBatteryView *batt = (CBCustomBatteryView *)[self viewWithTag:9999];
        if (batt && [batt respondsToSelector:@selector(resetSnapshot)]) {
            [batt resetSnapshot];
        }
    }
}

- (void)layoutSubviews {
    %orig;

    NSNumber *isLowPowerTarget = objc_getAssociatedObject(self, &kIsLowPowerKey);
    if (!isLowPowerTarget) {
        BOOL matched = NO;
        NSString *pkgName = [self respondsToSelector:@selector(packageName)] ? [self performSelector:@selector(packageName)] : @"";
        if (pkgName && [pkgName isKindOfClass:[NSString class]]) {
            matched = [pkgName containsString:@"LowPower"] || [pkgName containsString:@"Battery"];
        }

        if (!matched) {
            for (UIResponder *r = self; r; r = r.nextResponder) {
                NSString *cls = NSStringFromClass([r class]);
                if ([cls containsString:@"LowPowerModule"]) {
                    matched = YES;
                    break;
                }
            }
        }

        isLowPowerTarget = @(matched);
        objc_setAssociatedObject(self, &kIsLowPowerKey, isLowPowerTarget, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!isLowPowerTarget.boolValue) return;

    CBCustomBatteryView *batteryView = (CBCustomBatteryView *)[self viewWithTag:9999];
    if (!batteryView) {
        batteryView = [[CBCustomBatteryView alloc] initWithFrame:self.bounds];
        batteryView.tag = 9999;
        [self addSubview:batteryView];

        for (UIView *subview in self.subviews) {
            if (subview != batteryView && !subview.hidden) {
                subview.hidden = YES;
            }
        }
    }

    batteryView.frame = self.bounds;
}

%end