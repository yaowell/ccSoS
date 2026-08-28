#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIContentModuleContainerView : UIView
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updatePercentText;
- (BOOL)cb_isLowPowerModule;
@end

%hook CCUIContentModuleContainerView

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)layoutSubviews {
    %orig;

    // 严谨校验：非低电量模块直接隐藏 Label 并返回
    if (![self cb_isLowPowerModule]) {
        if (self.cbPercentLabel) {
            self.cbPercentLabel.hidden = YES;
        }
        return;
    }

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0 || width > 100 || height > 100) return;

    // 1. 图标向上平移 6pt
    for (UIView *subview in self.subviews) {
        if (subview != self.cbPercentLabel) {
            subview.transform = CGAffineTransformMakeTranslation(0, -6);
        }
    }

    // 2. 初始化/显示电量 Label
    if (!self.cbPercentLabel) {
        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, height - 16, width, 12)];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        lab.textColor = [UIColor whiteColor];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.userInteractionEnabled = NO;

        self.cbPercentLabel = lab;
        [self addSubview:lab];

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cb_updatePercentText)
                                                     name:UIDeviceBatteryLevelDidChangeNotification
                                                   object:nil];
    } else {
        self.cbPercentLabel.hidden = NO;
        self.cbPercentLabel.frame = CGRectMake(0, height - 16, width, 12);
    }

    [self bringSubviewToFront:self.cbPercentLabel];
    [self cb_updatePercentText];
}

%new
- (BOOL)cb_isLowPowerModule {
    // A. 检查 accessibilityIdentifier 或 accessibilityLabel
    if ([self.accessibilityIdentifier containsString:@"low-power"] || 
        [self.accessibilityLabel containsString:@"低电量"] || 
        [self.accessibilityLabel containsString:@"Low Power"]) {
        return YES;
    }

    // B. 递归检索子 View 链条与描述信息
    return [self cb_checkViewRecursive:self];
}

%new
- (BOOL)cb_checkViewRecursive:(UIView *)view {
    if (!view) return NO;

    NSString *className = NSStringFromClass([view class]);
    NSString *description = [view description];

    if ([className containsString:@"LowPower"] || 
        [className containsString:@"Battery"] || 
        [description containsString:@"low-power"] ||
        [description containsString:@"LowPower"]) {
        return YES;
    }

    for (UIView *subview in view.subviews) {
        if (subview == self.cbPercentLabel) continue;
        if ([self cb_checkViewRecursive:subview]) {
            return YES;
        }
    }
    return NO;
}

%new
- (void)cb_updatePercentText {
    dispatch_async(dispatch_get_main_queue(), ^{
        float level = [UIDevice currentDevice].batteryLevel;
        int percent = (level >= 0) ? (int)round(level * 100.0f) : 100;
        if (self.cbPercentLabel) {
            self.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%", percent];
        }
    });
}

%end
