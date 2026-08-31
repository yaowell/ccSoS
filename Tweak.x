#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

extern NSString* const kCAFilterDestOut;

@interface NSObject (Private)
- (BOOL)isSelected;
@end

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUIToggleViewController : UIViewController
@property (nonatomic, assign) BOOL isLowPowerModule;
@property (nonatomic, retain) UILabel *percentLabel;
@property (nonatomic, retain) NSObject *module;
- (void)refreshState;
@end

// 核心：递归遍历 CAPackage 图层，强行修改 Fill 填充层的 Width（容量）和 FillColor（颜色）
static void updateBatteryPackageView(UIView *view, float batteryLevel, BOOL isSelected) {
    if (!view) return;

    if ([NSStringFromClass([view class]) containsString:@"CCUICAPackageView"]) {
        CALayer *mainLayer = view.layer;
        NSMutableArray *nodes = [NSMutableArray arrayWithObject:mainLayer];

        while (nodes.count > 0) {
            CALayer *node = [nodes firstObject];
            [nodes removeObjectAtIndex:0];

            NSString *layerName = node.name ?: @"";
            
            // 匹配 CAPackage 内部代表电池填充条的 Layer (Fill / Level)
            if ([layerName containsString:@"Fill"] || [layerName containsString:@"fill"] || [layerName containsString:@"Level"]) {
                
                // 1. 动态改变填充条长度 (容量)
                CGFloat maxW = node.superlayer ? node.superlayer.bounds.size.width : node.bounds.size.width;
                if (maxW > 0) {
                    CGRect f = node.frame;
                    f.size.width = maxW * batteryLevel;
                    node.frame = f;
                }

                // 2. 动态改变填充条颜色 (低于20%变红)
                if ([node isKindOfClass:[CAShapeLayer class]]) {
                    CAShapeLayer *shapeLayer = (CAShapeLayer *)node;
                    int batteryInt = (int)round(batteryLevel * 100);

                    if (isSelected) {
                        // 开启低电量：黄色
                        shapeLayer.fillColor = [UIColor systemYellowColor].CGColor;
                    } else if (batteryInt <= 20) {
                        // 未开启且电量 <= 20%：填充条强行染红！
                        shapeLayer.fillColor = [UIColor systemRedColor].CGColor;
                    } else {
                        // 正常电量：白色
                        shapeLayer.fillColor = [UIColor whiteColor].CGColor;
                    }
                }
            }

            if (node.sublayers) {
                [nodes addObjectsFromArray:node.sublayers];
            }
        }
        return;
    }

    for (UIView *subview in view.subviews) {
        updateBatteryPackageView(subview, batteryLevel, isSelected);
    }
}

%hook CCUIToggleViewController
%property (nonatomic, assign) BOOL isLowPowerModule;
%property (nonatomic, retain) UILabel *percentLabel;

- (void)viewDidLoad {
    %orig;

    if ([self.module isKindOfClass:NSClassFromString(@"CCUILowPowerModule")]) {
        self.isLowPowerModule = YES;
    }

    if (self.isLowPowerModule) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        // 原版 Cowbell 百分比 Label
        UILabel *label = [[UILabel alloc] init];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;
        label.layer.compositingFilter = kCAFilterDestOut;

        [self.view addSubview:label];
        self.percentLabel = label;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);

    if (self.isLowPowerModule && self.percentLabel) {
        float level = [[UIDevice currentDevice] batteryLevel];
        float safeLevel = (level < 0) ? 1.0 : level;
        int battery = (int)round(safeLevel * 100);

        // 刷新百分比数字文本
        self.percentLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.percentLabel sizeToFit];

        CGFloat viewW = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : 72.0;
        CGFloat viewH = self.view.bounds.size.height > 0 ? self.view.bounds.size.height : 72.0;
        CGFloat labelW = self.percentLabel.frame.size.width;
        CGFloat labelH = self.percentLabel.frame.size.height;

        self.percentLabel.frame = CGRectMake(
            (viewW - labelW) / 2.0,
            viewH * 0.70,
            labelW,
            labelH
        );

        // 刷新电池图标：传参当前电量比例 + 开启状态
        BOOL isSelected = [self.module isSelected];
        updateBatteryPackageView(self.view, safeLevel, isSelected);

        [self refreshState];
    }
}

- (void)refreshState {
    %orig;

    if (self.isLowPowerModule && self.percentLabel) {
        BOOL isSelected = [self.module isSelected];
        
        // 原版 Cowbell 的文字滤镜逻辑
        if (isSelected) {
            self.percentLabel.layer.compositingFilter = kCAFilterDestOut;
        } else {
            self.percentLabel.layer.compositingFilter = nil;
        }

        // 状态切换时同步更新电池填充条颜色与容量
        float level = [[UIDevice currentDevice] batteryLevel];
        float safeLevel = (level < 0) ? 1.0 : level;
        updateBatteryPackageView(self.view, safeLevel, isSelected);
    }
}

%end

#pragma clang diagnostic pop
