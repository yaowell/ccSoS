#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kIsLowPowerKey;

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

@interface CBCustomBatteryView : UIView
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, assign) int cachedPercent;
@property (nonatomic, assign) BOOL cachedLowPowerState;
@property (nonatomic, assign) BOOL needFreshData;
- (void)updateColorsOnly;
@end

@implementation CBCustomBatteryView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.cachedPercent = -1;
        self.cachedLowPowerState = NO;
        self.needFreshData = YES;
        
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
        self.needFreshData = YES;
        [nc addObserver:self selector:@selector(updateColorsOnly) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    } else {
        [nc removeObserver:self name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    }
}

- (void)updateColorsOnly {
    if(!self.window) return;
    dispatch_async(dispatch_get_main_queue(),^{
        [self setNeedsLayout];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if(self.needFreshData){
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        float level = [UIDevice currentDevice].batteryLevel;
        if(level < 0) level = 1.0f;
        self.cachedPercent = (int)round(level * 100);
        self.percentLabel.text = [NSString stringWithFormat:@"%d%%",self.cachedPercent];
        self.needFreshData = NO;
    }
    
    BOOL currentState = [NSProcessInfo processInfo].isLowPowerModeEnabled;
    if(self.cachedLowPowerState != currentState){
        self.cachedLowPowerState = currentState;
        self.percentLabel.textColor = currentState ? [UIColor blackColor] : [UIColor whiteColor];
    }
    
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    [self.percentLabel sizeToFit];
    self.percentLabel.frame = CGRectMake((w - self.percentLabel.bounds.size.width)/2.0f, h * 0.82, self.percentLabel.bounds.size.width, self.percentLabel.bounds.size.height);
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