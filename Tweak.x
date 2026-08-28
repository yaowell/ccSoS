#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIContentModuleContainerView : UIView
@property (nonatomic, strong) NSString *moduleIdentifier;
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updatePercentText;
- (BOOL)cb_isLowPowerModule;
- (UIImageView *)cb_findImageViewInView:(UIView *)view;
@end

%hook CCUIContentModuleContainerView

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)layoutSubviews {
    %orig;

    if (![self cb_isLowPowerModule]) {
        if (self.cbPercentLabel) {
            self.cbPercentLabel.hidden = YES;
        }
        return;
    }

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0 || width > 100 || height > 100) return;

    for (UIView *subview in self.subviews) {
        if (subview != self.cbPercentLabel) {
            subview.transform = CGAffineTransformIdentity;
        }
    }

    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, height - 22, width, 12)];
        lab.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        self.cbPercentLabel = lab;
        [self addSubview:lab];

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cb_updatePercentText)
                                                     name:UIDeviceBatteryLevelDidChangeNotification
                                                   object:nil];
                                                   
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cb_updatePercentText)
                                                     name:NSProcessInfoPowerStateDidChangeNotification
                                                   object:nil];
    } else {
        self.cbPercentLabel.hidden = NO;
        self.cbPercentLabel.frame = CGRectMake(0, height - 22, width, 12);
    }

    [self bringSubviewToFront:self.cbPercentLabel];
    [self cb_updatePercentText];
}

%new
- (BOOL)cb_isLowPowerModule {
    if ([self respondsToSelector:@selector(moduleIdentifier)]) {
        NSString *modID = [self performSelector:@selector(moduleIdentifier)];
        if ([modID isEqualToString:@"com.apple.control-center.LowPowerModule"] || 
            [modID containsString:@"LowPowerModule"]) {
            return YES;
        }
    }

    UIResponder *responder = self;
    while (responder) {
        NSString *clsName = NSStringFromClass([responder class]);
        if ([clsName containsString:@"CCUILowPowerModeModule"]) {
            return YES;
        }
        responder = [responder nextResponder];
    }

    return NO;
}

%new
- (UIImageView *)cb_findImageViewInView:(UIView *)view {
    if ([view isKindOfClass:[UIImageView class]]) {
        return (UIImageView *)view;
    }
    for (UIView *subview in view.subviews) {
        UIImageView *imgView = [self cb_findImageViewInView:subview];
        if (imgView) return imgView;
    }
    return nil;
}

%new
- (void)cb_updatePercentText {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.cbPercentLabel) return;

        // 1. 获取当前电量百分比
        float level = [UIDevice currentDevice].batteryLevel;
        int percent = (level >= 0) ? (int)round(level * 100.0f) : 100;
        self.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%", percent];

        // 2. 状态切换颜色
        BOOL isLowPowerMode = [NSProcessInfo processInfo].isLowPowerModeEnabled;
        self.cbPercentLabel.textColor = isLowPowerMode ? [UIColor blackColor] : [UIColor whiteColor];

        // 3. 动态更换 SF Symbol 电池图标
        UIImageView *iconImageView = [self cb_findImageViewInView:self];
        if (iconImageView) {
            NSString *symbolName = @"battery.100";
            if (percent <= 15) {
                symbolName = @"battery.0";
            } else if (percent <= 35) {
                symbolName = @"battery.25";
            } else if (percent <= 65) {
                symbolName = @"battery.50";
            } else if (percent <= 85) {
                symbolName = @"battery.75";
            } else {
                symbolName = @"battery.100";
            }

            UIImage *newImage = [UIImage systemImageNamed:symbolName];
            if (newImage && iconImageView.image != newImage) {
                iconImageView.image = newImage;
            }
        }
    });
}

%end
