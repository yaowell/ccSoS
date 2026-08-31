#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUIButtonModuleView : UIView
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, retain) UILabel *cowbellLabel;
@end

%hook CCUIButtonModuleView
%property (nonatomic, retain) UILabel *cowbellLabel;

- (void)layoutSubviews {
    %orig;

    // 判断该按钮容器是否属于低电量模块（根据控制器响应链）
    UIResponder *responder = self.nextResponder;
    BOOL isLowPowerModule = NO;
    while (responder) {
        if ([NSStringFromClass([responder class]) containsString:@"LowPower"]) {
            isLowPowerModule = YES;
            break;
        }
        responder = responder.nextResponder;
    }

    // 只有低电量模块才注入电量标签
    if (!isLowPowerModule) return;

    if (!self.cowbellLabel) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;

        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;

        [self addSubview:label];
        self.cowbellLabel = label;
    }

    if (self.cowbellLabel) {
        // 1. 获取当前设备电量
        float level = [UIDevice currentDevice].batteryLevel;
        int battery = (level < 0) ? 100 : (int)round(level * 100);
        self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.cowbellLabel sizeToFit];

        // 2. 居中定位在 72x72 图标偏下方
        CGFloat w = self.bounds.size.width > 0 ? self.bounds.size.width : 72.0;
        CGFloat h = self.bounds.size.height > 0 ? self.bounds.size.height : 72.0;
        self.cowbellLabel.center = CGPointMake(w / 2.0, h * 0.72);

        // 3. 处理颜色变红与 GPU 镂空逻辑
        if (self.selected) {
            // 开启低电量模式：开启 GPU 挖空滤镜
            self.cowbellLabel.textColor = [UIColor whiteColor];
            self.cowbellLabel.layer.compositingFilter = kCAFilterDestOut;
        } else {
            // 未开启低电量模式：关闭滤镜
            self.cowbellLabel.layer.compositingFilter = nil;

            if (battery <= 20) {
                // 低于或等于 20%：显示警告红字
                self.cowbellLabel.textColor = [UIColor systemRedColor];
            } else {
                // 正常电量：显示白色
                self.cowbellLabel.textColor = [UIColor whiteColor];
            }
        }

        [self bringSubviewToFront:self.cowbellLabel];
    }
}

%end

#pragma clang diagnostic pop
