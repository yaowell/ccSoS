#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIBatteryView : UIView
@property (nonatomic, strong) UILabel *cb_percentLabel;
- (void)cb_setupBatteryMonitoring;
@end

%hook CCUIBatteryView

%property (nonatomic, strong) UILabel *cb_percentLabel;

- (instancetype)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        [self cb_setupBatteryMonitoring];
    }
    return self;
}

- (void)layoutSubviews {
    %orig;

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    UILabel *label = self.cb_percentLabel;
    if (!label) {
        label = [[UILabel alloc] init];
        label.font = [UIFont boldSystemFontOfSize:9.0];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = [UIColor clearColor];
        label.userInteractionEnabled = NO;
        
        self.cb_percentLabel = label;
        [self addSubview:label];
    }

    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0f) : 0;

    if (level >= 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"";
    }

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    CGFloat insetX = 2.0f;
    CGFloat insetY = 1.0f;
    label.frame = CGRectMake(insetX, insetY,
                             CGRectGetWidth(self.bounds) - insetX * 2,
                             CGRectGetHeight(self.bounds) - insetY * 2);

    [self bringSubviewToFront:label];
}

%new
- (void)cb_setupBatteryMonitoring {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setNeedsLayout)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setNeedsLayout)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
}

%end

%ctor {
    NSLog(@"[SimpleCowbell] Loaded into process: %@", [[NSBundle mainBundle] bundleIdentifier]);
}
