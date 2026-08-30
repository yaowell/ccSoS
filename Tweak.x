#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface CBCustomBatteryView : UIView
@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) CAShapeLayer *bodyBorderLayer;
@property (nonatomic, strong) CAShapeLayer *capLayer;
@property (nonatomic, assign) CGRect lastBounds;
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
        self.lastBounds = CGRectZero;
        self.lastPercent = -1;
        self.lastLowPowerState = NO;
        
        _bodyBorderLayer = [CAShapeLayer layer];
        _bodyBorderLayer.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:_bodyBorderLayer];

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

- (void)didMoveToWindow {
    [super didMoveToWindow];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if (self.window) {
        if (![UIDevice currentDevice].isBatteryMonitoringEnabled) {
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        }
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
    [self setNeedsLayout];
}

- (void)updateLayoutIfBoundsChanged {
    if (CGRectEqualToRect(self.bounds, self.lastBounds) || self.bounds.size.width <= 0) return;
    self.lastBounds = self.bounds;

    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    CGFloat scale = MIN(h / 72.0f, w / 64.0f);

    CGFloat totalW = 32.0f * scale;
    CGFloat iconH = 14.0f * scale;
    CGFloat iconX = (w - totalW) / 2.0f;
    CGFloat iconY = (h - iconH) / 2.0f - (1.0f * scale);
    CGRect iconRect = CGRectMake(iconX, iconY, totalW, iconH);

    CGFloat bodyW = iconRect.size.width - (3.3f * scale);
    CGFloat lineWidth = 1.4f * scale;
    CGFloat radius = 4.2f * scale;

    UIBezierPath *bodyPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(iconRect.origin.x, iconRect.origin.y, bodyW, iconRect.size.height) cornerRadius:radius];
    self.bodyBorderLayer.path = bodyPath.CGPath;
    self.bodyBorderLayer.lineWidth = lineWidth;

    CGFloat capW = 1.8f * scale;
    CGFloat capH = 4.8f * scale;
    CGFloat capX = iconRect.origin.x + bodyW + (1.5f * scale);
    CGFloat capY = iconRect.origin.y + (iconRect.size.height - capH) / 2.0f;
    CGFloat capRadius = 1.2f * scale;

    UIBezierPath *capPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(capX, capY, capW, capH)
                                                  byRoundingCorners:(UIRectCornerTopRight | UIRectCornerBottomRight)
                                                        cornerRadii:CGSizeMake(capRadius, capRadius)];
    self.capLayer.path = capPath.CGPath;

    self.percentLabel.font = [UIFont systemFontOfSize:9.3f * scale weight:UIFontWeightRegular];
    self.percentLabel.frame = CGRectMake(0, iconRect.origin.y + iconRect.size.height + (5.5f * scale), w, 11.0f * scale);
}

- (void)updateBatteryUI {
    BOOL boundsChanged = !CGRectEqualToRect(self.bounds, self.lastBounds);
    [self updateLayoutIfBoundsChanged];

    float level = [UIDevice currentDevice].batteryLevel;
    if (level < 0) level = 1.0f;
    int currentPercent = (int)round(level * 100);
    BOOL isLowPower = [NSProcessInfo processInfo].isLowPowerModeEnabled;

    if (!boundsChanged && currentPercent == self.lastPercent && isLowPower == self.lastLowPowerState) {
        return;
    }

    self.lastPercent = currentPercent;
    self.lastLowPowerState = isLowPower;
    self.percentLabel.text = [NSString stringWithFormat:@"%d%%", currentPercent];

    UIColor *themeColor = isLowPower ? [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0] : [UIColor whiteColor];
    UIColor *strokeColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    self.percentLabel.textColor = strokeColor;
    self.fillView.backgroundColor = themeColor;
    self.bodyBorderLayer.strokeColor = strokeColor.CGColor;
    self.capLayer.fillColor = strokeColor.CGColor;

    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    CGFloat scale = MIN(h / 72.0f, w / 64.0f);
    CGFloat totalW = 32.0f * scale;
    CGFloat iconH = 14.0f * scale;
    CGFloat iconX = (w - totalW) / 2.0f;
    CGFloat iconY = (h - iconH) / 2.0f - (1.0f * scale);

    CGFloat bodyW = totalW - (3.3f * scale);
    CGFloat padding = 2.0f * scale;
    CGFloat currentFillW = MAX((bodyW - padding * 2.0f) * level, 2.0f * scale);

    self.fillView.frame = CGRectMake(iconX + padding, iconY + padding, currentFillW, iconH - padding * 2.0f);
    self.fillView.layer.cornerRadius = 2.0f * scale;
    
    [CATransaction commit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateBatteryUI];
}

@end

%hook CCUILowPowerModeModuleViewController

- (void)viewDidLayoutSubviews {
    %orig;

    UIView *glyphView = [self respondsToSelector:@selector(glyphView)] ? [self performSelector:@selector(glyphView)] : nil;
    if (!glyphView) glyphView = self.view;

    // 隐藏原生图标层的透明度，但不影响点击响应和状态机
    for (CALayer *sublayer in glyphView.layer.sublayers) {
        if (sublayer.delegate && [NSStringFromClass([sublayer.delegate class]) containsString:@"Package"]) {
            sublayer.hidden = YES;
        }
    }

    CBCustomBatteryView *batteryView = [glyphView viewWithTag:9999];
    if (!batteryView) {
        batteryView = [[CBCustomBatteryView alloc] initWithFrame:glyphView.bounds];
        batteryView.tag = 9999;
        [glyphView addSubview:batteryView];
    }

    batteryView.frame = glyphView.bounds;
    batteryView.hidden = NO;
    [glyphView bringSubviewToFront:batteryView];
}

%end
