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

// 递归寻找并修正电池 PackageView 内部的电量填充 Layer 宽度
static void updateBatteryFillLayer(CALayer *layer, float batteryLevel) {
    if (!layer) return;

    NSString *name = layer.name ?: @"";
    // iOS 16 控制中心电池 CAPackage 内部的填充层 Layer 名称通常带有 Fill / Level 标识
    if ([name containsString:@"Fill"] || [name containsString:@"fill"] || [name containsString:@"Level"]) {
        // 获取父图层的宽度作为最大填充基准
        CGFloat parentWidth = layer.superlayer ? layer.superlayer.bounds.size.width : layer.bounds.size.width;
        if (parentWidth > 0) {
            CGRect frame = layer.frame;
            // 实时按电量百分比计算填充条宽度
            frame.size.width = parentWidth * batteryLevel;
            layer.frame = frame;
        }
    }

    for (CALayer *sublayer in layer.sublayers) {
        updateBatteryFillLayer(sublayer, batteryLevel);
    }
}

// 递归找到 CCUICAPackageView 并更新其 Layer
static void processPackageView(UIView *view, float batteryLevel) {
    if (!view) return;
    if ([NSStringFromClass([view class]) containsString:@"CCUICAPackageView"]) {
        updateBatteryFillLayer(view.layer, batteryLevel);
        return;
    }
    for (UIView *subview in view.subviews) {
        processPackageView(subview, batteryLevel);
    }
}

%hook CCUIButtonModuleView
%property (nonatomic, retain) UILabel *cowbellLabel;

- (void)layoutSubviews {
    %orig;

    // 向上检索响应链，只对低电量模块生效
    UIResponder *responder = self.nextResponder;
    BOOL isLowPowerModule = NO;
    while (responder) {
        if ([NSStringFromClass([responder class]) containsString:@"LowPower"]) {
            isLowPowerModule = YES;
            break;
        }
        responder = responder.nextResponder;
    }

    if (!isLowPowerModule) return;

    // 1. 获取设备电量
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    float safeLevel = (level < 0) ? 1.0 : level;
    int battery = (int)round(safeLevel * 100);

    // 2. 动态调节内部电池图标填充条的长度
    processPackageView(self, safeLevel);

    // 3. 挂载并在图标正下方渲染百分比文字
    if (!self.cowbellLabel) {
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
        self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.cowbellLabel sizeToFit];

        // 居中挂载在图标下方（对应实机图 87% 的位置）
        CGFloat w = self.bounds.size.width > 0 ? self.bounds.size.width : 72.0;
        CGFloat h = self.bounds.size.height > 0 ? self.bounds.size.height : 72.0;
        self.cowbellLabel.center = CGPointMake(w / 2.0, h * 0.73);

        // 4. 颜色与 GPU 挖空逻辑
        if (self.selected) {
            // 开启低电量状态：白色文字 + GPU 挖空
            self.cowbellLabel.textColor = [UIColor whiteColor];
            self.cowbellLabel.layer.compositingFilter = kCAFilterDestOut;
        } else {
            // 关闭低电量状态：正常透明度/颜色
            self.cowbellLabel.layer.compositingFilter = nil;

            if (battery <= 20) {
                self.cowbellLabel.textColor = [UIColor systemRedColor];
            } else {
                self.cowbellLabel.textColor = [UIColor whiteColor];
            }
        }

        [self bringSubviewToFront:self.cowbellLabel];
    }
}

%end

#pragma clang diagnostic pop
