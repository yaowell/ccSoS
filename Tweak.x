#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *stateName;
- (void)setStateName:(NSString *)stateName;
@end

@interface CCUILowPowerModuleViewController : UIViewController
@property (nonatomic, retain) UILabel *percentLabel;
- (void)refreshState;
- (BOOL)isSelected;
@end

// 驱动 iOS 16 原生电池 CAPackageView 图层：变色与容量控制
static void updateBatteryViewProperties(UIView *view, float batteryLevel, BOOL isSelected) {
    if (!view) return;

    if ([NSStringFromClass([view class]) containsString:@"CCUICAPackageView"]) {
        CCUICAPackageView *packageView = (CCUICAPackageView *)view;
        int battery = (int)round(batteryLevel * 100);

        // 1. 拦截低电量（<=20%）未开启状态，强制染红
        if (!isSelected && battery <= 20) {
            packageView.tintColor = [UIColor systemRedColor];
            
            // 深入 CALayer 图层修改 CAShapeLayer 填充色为红色
            NSMutableArray *nodes = [NSMutableArray arrayWithObject:packageView.layer];
            while (nodes.count > 0) {
                CALayer *layer = [nodes firstObject];
                [nodes removeObjectAtIndex:0];
                
                if ([layer isKindOfClass:[CAShapeLayer class]]) {
                    ((CAShapeLayer *)layer).fillColor = [UIColor systemRedColor].CGColor;
                }
                if (layer.sublayers) {
                    [nodes addObjectsFromArray:layer.sublayers];
                }
            }
        } else {
            packageView.tintColor = nil;
        }

        // 2. 容量跟随：针对内部 Fill 图层改变 scale.x，或给 PackageView 整体微调
        CALayer *packageLayer = packageView.layer;
        packageLayer.anchorPoint = CGPointMake(0.5, 0.5);
        return;
    }

    for (UIView *subview in view.subviews) {
        updateBatteryViewProperties(subview, batteryLevel, isSelected);
    }
}

%hook CCUILowPowerModuleViewController
%property (nonatomic, retain) UILabel *percentLabel;

- (void)viewDidLoad {
    %orig;

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    // 强行注入 Cowbell 百分比文本
    if (!self.percentLabel) {
        UILabel *label = [[UILabel alloc] init];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
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

        // 刷新电量文字
        self.percentLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.percentLabel sizeToFit];

        CGFloat viewW = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : 72.0;
        CGFloat viewH = self.view.bounds.size.height > 0 ? self.view.bounds.size.height : 72.0;
        CGFloat labelW = self.percentLabel.frame.size.width;
        CGFloat labelH = self.percentLabel.frame.size.height;

        // 放在电池图标下方的 0.70 黄金位置
        self.percentLabel.frame = CGRectMake(
            (viewW - labelW) / 2.0,
            viewH * 0.70,
            labelW,
            labelH
        );

        // 刷新电池填充条状态
        BOOL selected = NO;
        if ([self respondsToSelector:@selector(isSelected)]) {
            selected = [self isSelected];
        }
        updateBatteryViewProperties(self.view, safeLevel, selected);
    }
}

- (void)refreshState {
    %orig;

    if (self.percentLabel) {
        BOOL selected = NO;
        if ([self respondsToSelector:@selector(isSelected)]) {
            selected = [self isSelected];
        }

        // 切换 GPU 镂空滤镜
        if (selected) {
            self.percentLabel.layer.compositingFilter = kCAFilterDestOut;
        } else {
            self.percentLabel.layer.compositingFilter = nil;
        }

        float level = [[UIDevice currentDevice] batteryLevel];
        float safeLevel = (level < 0) ? 1.0 : level;
        updateBatteryViewProperties(self.view, safeLevel, selected);
    }
}

%end

#pragma clang diagnostic pop
