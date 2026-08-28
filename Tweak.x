#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIContentModuleContainerView : UIView
@property (nonatomic, strong) NSString *moduleIdentifier;
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updatePercentText;
- (BOOL)cb_isLowPowerModule;
@end

%hook CCUIContentModuleContainerView

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)layoutSubviews {
    %orig;

    // 1. 如果不是低电量模块，直接隐藏 Label 并返回
    if (![self cb_isLowPowerModule]) {
        if (self.cbPercentLabel) {
            self.cbPercentLabel.hidden = YES;
        }
        return;
    }

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    if (width <= 0 || height <= 0 || width > 100 || height > 100) return;

    // 2. 将低电量图标向上平移 6pt
    for (UIView *subview in self.subviews) {
        if (subview != self.cbPercentLabel) {
            subview.transform = CGAffineTransformMakeTranslation(0, -6);
        }
    }

    // 3. 创建/显示底部的白色电量 Label
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
    // A. 优先检查 CCUIContentModuleContainerView 自带的 moduleIdentifier 私有属性
    if ([self respondsToSelector:@selector(moduleIdentifier)]) {
        NSString *modID = [self performSelector:@selector(moduleIdentifier)];
        if ([modID containsString:@"LowPower"] || [modID containsString:@"low-power"] || [modID containsString:@"battery"]) {
            return YES;
        }
    }

    // B. 检查 View 的 responder 链条中的 Controller 类名
    UIResponder *responder = self;
    while (responder) {
        NSString *clsName = NSStringFromClass([responder class]);
        if ([clsName containsString:@"LowPower"] || [clsName containsString:@"Battery"]) {
            return YES;
        }
        responder = [responder nextResponder];
    }

    // C. 检查 accessibility 标识
    if ([self.accessibilityIdentifier containsString:@"low-power"] || 
        [self.accessibilityLabel containsString:@"低电量"] || 
        [self.accessibilityLabel containsString:@"Low Power"]) {
        return YES;
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
