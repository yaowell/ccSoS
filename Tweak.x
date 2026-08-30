#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kIsLowPowerKey;

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

@interface CBCustomBatteryView : UIView
@property (nonatomic, strong) UILabel *percentLabel;
- (void)updateColorOnly;
@end

@implementation CBCustomBatteryView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        
        _percentLabel = [[UILabel alloc] init];
        _percentLabel.textAlignment = NSTextAlignmentCenter;
        _percentLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        [self addSubview:_percentLabel];
    }
    return self;
}

- (void)updateColorOnly {
    // 只更新文字颜色，**不去读取电量数值**，电量依旧只在didMoveToWindow刷新
    BOOL lowPowerOn = [NSProcessInfo processInfo].isLowPowerModeEnabled;
    self.percentLabel.textColor = lowPowerOn ? [UIColor blackColor] : [UIColor whiteColor];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if(self.window) {
        // 视图显示：读取一次电量数值
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        float level = [UIDevice currentDevice].batteryLevel;
        if(level < 0) level = 1.0f;
        int percent = (int)round(level * 100);
        BOOL lowPowerOn = [NSProcessInfo processInfo].isLowPowerModeEnabled;
        
        self.percentLabel.text = [NSString stringWithFormat:@"%d%%", percent];
        self.percentLabel.textColor = lowPowerOn ? [UIColor blackColor] : [UIColor whiteColor];
        
        // 仅监听【低电量开关切换通知】，不监听电量变化！
        [nc addObserver:self selector:@selector(updateColorOnly) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    } else {
        // 视图离开屏幕，移除通知，避免内存泄漏
        [nc removeObserver:self name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.percentLabel) {
        [self.percentLabel sizeToFit];
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        self.percentLabel.frame = CGRectMake((w - self.percentLabel.bounds.size.width)/2.0, h * 0.70, self.percentLabel.bounds.size.width, self.percentLabel.bounds.size.height);
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

%hook CCUICAPackageView

- (void)layoutSubviews {
    %orig;

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

    self.backgroundColor = [UIColor clearColor];

    CBCustomBatteryView *batteryView = [self viewWithTag:9999];
    if (!batteryView) {
        batteryView = [[CBCustomBatteryView alloc] initWithFrame:self.bounds];
        batteryView.tag = 9999;
        [self addSubview:batteryView];
    }

    batteryView.frame = self.bounds;
    batteryView.hidden = NO;
    batteryView.alpha = 1.0f;
}

%end