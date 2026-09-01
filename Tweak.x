#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString *const kCAFilterDestOut;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

static char kCowbellPercentLabelKey;
static char kCowbellIsLowPowerKey;

static CGFloat const COWBELL_PERCENT_Y_OFFSET = 12.0;

static UILabel *CowbellGetLabel(CCUICAPackageView *view) {
    return objc_getAssociatedObject(view, &kCowbellPercentLabelKey);
}

static void CowbellUpdatePercent(CCUICAPackageView *view) {
    if (!view) return;
    UILabel *label = CowbellGetLabel(view);
    if (!label || !label.window) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!label.window) return;

        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }

        float level = UIDevice.currentDevice.batteryLevel;
        if (level < 0) level = 1.0f;
        int percent = (int)round(level * 100.0f);

        label.text = [NSString stringWithFormat:@"%d%%", percent];

        BOOL lowPower = [NSProcessInfo processInfo].isLowPowerModeEnabled;
        label.textColor = lowPower ? [UIColor blackColor] : [UIColor whiteColor];

        CAFilter *filter = [CAFilter filterWithType:kCAFilterDestOut];
        label.layer.filters = @[filter];

        [label setNeedsLayout];
    });
}

static BOOL CowbellIsLowPowerPackage(CCUICAPackageView *view) {
    NSNumber *cached = objc_getAssociatedObject(view, &kCowbellIsLowPowerKey);
    if (cached) return cached.boolValue;

    BOOL matched = NO;
    NSString *pkgName = @"";
    if ([view respondsToSelector:@selector(packageName)]) {
        pkgName = view.packageName ?: @"";
    }

    if ([pkgName containsString:@"LowPower"] || [pkgName containsString:@"Battery"]) {
        matched = YES;
    }

    if (!matched) {
        for (UIResponder *r = view; r; r = [r nextResponder]) {
            NSString *cls = NSStringFromClass([r class]);
            if ([cls containsString:@"Brightness"] || [cls containsString:@"Display"]) break;
            if ([cls containsString:@"LowPower"]) {
                matched = YES;
                break;
            }
        }
    }

    objc_setAssociatedObject(view, &kCowbellIsLowPowerKey, @(matched), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return matched;
}

static UILabel *CowbellCreateLabel(CCUICAPackageView *view) {
    UILabel *label = CowbellGetLabel(view);
    if (label) return label;

    label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];

    CAFilter *filter = [CAFilter filterWithType:kCAFilterDestOut];
    label.layer.filters = @[filter];
    label.tag = 9998;

    [view addSubview:label];

    objc_setAssociatedObject(view, &kCowbellPercentLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        CowbellUpdatePercent(view);
    }];
    [nc addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        CowbellUpdatePercent(view);
    }];

    return label;
}

%hook CCUICAPackageView

- (void)layoutSubviews {
    %orig;

    if (!CowbellIsLowPowerPackage(self)) return;

    if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    }

    UILabel *label = CowbellCreateLabel(self);
    if (!label) return;

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0) return;

    CGFloat centerY = height * 0.5f;
    CGFloat y = centerY + COWBELL_PERCENT_Y_OFFSET;

    label.frame = CGRectMake(0, y, width, 11.0f);
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];

    [self bringSubviewToFront:label];
    CowbellUpdatePercent(self);
}

- (void)didMoveToWindow {
    %orig;

    if (!CowbellIsLowPowerPackage(self)) return;

    if (self.window) {
        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }

        UILabel *label = CowbellGetLabel(self);
        if (label) {
            label.hidden = NO;
            label.alpha = 1.0f;
            CowbellUpdatePercent(self);
        }
    }
}

%end

#pragma clang diagnostic pop
