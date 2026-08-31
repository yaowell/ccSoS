#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

// 1. 补全 CALayer 私有属性接口（彻底解决编译报错）
@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUICAPackageView : UIView
@end

@interface CCUILowPowerModuleViewController : UIViewController
@property (nonatomic, retain) UILabel *percentLabel;
- (BOOL)isSelected;
@end

// 动态计算电池内部 CAPackage/ShapeLayer 的填充宽度与颜色
static void updateBatteryPackageView(UIView *view, float batteryLevel, BOOL isSelected) {
    if (!view) return;

    if ([NSStringFromClass([view class]) containsString:@"CCUICAPackageView"]) {
        int battery = (int)round(batteryLevel * 100);

        // 遍历 Package 内部的 CAShapeLayer 图层（电池芯）
        NSMutableArray *nodes = [NSMutableArray arrayWithObject:view.layer];
        while (nodes.count > 0) {
            CALayer *layer = [nodes firstObject];
            [nodes removeObjectAtIndex:0];

            NSString *layerName = layer.name ?: @"";

            // 匹配电池填充芯的图层名称
            if ([layerName containsString:@"Fill"] || [layerName containsString:@"fill"] || [layerName containsString:@"Level"]) {
                // A. 改变填充长度（容量跟着变）
                CGFloat maxW = layer.superlayer ? layer.superlayer.bounds.size.width : layer.bounds.size.width;
                if (maxW > 0) {
                    CGRect f = layer.frame;
                    f.size.width = maxW * batteryLevel;
                    layer.frame = f;
                }

                // B. 低于等于 20% 且未开启低电量模式时，强行染红
                if ([layer isKindOfClass:[CAShapeLayer class]]) {
                    CAShapeLayer *shapeLayer = (CAShapeLayer *)layer;
                    if (isSelected) {
                        shapeLayer.fillColor = [UIColor systemYellowColor].CGColor;
                    } else if (battery <= 20) {
                        shapeLayer.fillColor = [UIColor systemRedColor].CGColor;
                    } else {
                        shapeLayer.fillColor = [UIColor whiteColor].CGColor;
                    }
                }
            }

            if (layer.sublayers) {
                [nodes addObjectsFromArray:layer.sublayers];
            }
        }
        return;
    }

    for (UIView *subview in view.subviews) {
        updateBatteryPackageView(subview, batteryLevel, isSelected);
    }
}

%hook CCUILowPowerModuleViewController
%property (nonatomic, retain) UILabel *percentLabel;

- (void)viewDidLoad {
    %orig;

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    if (!self.percentLabel) {
        UILabel *label = [[UILabel alloc] init];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        
        // 避开直接调用私有属性，也可直接设置
        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;

        [self.view addSubview:label];
        self.percentLabel = label;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (self.percentLabel) {
        float level = [[UIDevice currentDevice] batteryLevel];
        float safeLevel = (level < 0) ? 1.0 : level;
        int battery = (int)round(safeLevel * 100);

        // 设置百分比文本
        self.percentLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.percentLabel sizeToFit];

        CGFloat viewW = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : 72.0;
        CGFloat viewH = self.view.bounds.size.height > 0 ? self.view.bounds.size.height : 72.0;
        CGFloat labelW = self.percentLabel.frame.size.width;
        CGFloat labelH = self.percentLabel.frame.size.height;

        // 放在电池图标正下方 0.70 位置
        self.percentLabel.frame = CGRectMake(
            (viewW - labelW) / 2.0,
            viewH * 0.70,
            labelW,
            labelH
        );

        BOOL selected = NO;
        if ([self respondsToSelector:@selector(isSelected)]) {
            selected = [self isSelected];
        }

        // 处理文字颜色与 GPU 镂空
        if (selected) {
            self.percentLabel.textColor = [UIColor whiteColor];
            self.percentLabel.layer.compositingFilter = kCAFilterDestOut;
        } else {
            self.percentLabel.layer.compositingFilter = nil;
            if (battery <= 20) {
                self.percentLabel.textColor = [UIColor systemRedColor];
            } else {
                self.percentLabel.textColor = [UIColor whiteColor];
            }
        }

        // 驱动原生 CAPackageView 图标的填充长度与颜色
        updateBatteryPackageView(self.view, safeLevel, selected);
    }
}

%end

#pragma clang diagnostic pop
