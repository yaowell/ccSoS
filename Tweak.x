#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

extern NSString* const kCAFilterDestOut;

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

// 视图层：控制中心按钮视图
@interface CCUIButtonModuleView : UIView
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@end

// 控制器层：iOS 16 低电量专用 VC
@interface CCUILowPowerModuleViewController : UIViewController
@property (nonatomic, retain) UILabel *cowbellLabel;
@end

%hook CCUILowPowerModuleViewController
%property (nonatomic, retain) UILabel *cowbellLabel;

- (void)viewDidLoad {
    %orig;

    if (!self.cowbellLabel) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;

        UILabel *label = [[UILabel alloc] init];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;

        // Cowbell 核心：GPU 混合镂空
        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;
        label.layer.compositingFilter = kCAFilterDestOut;

        [self.view addSubview:label];
        self.cowbellLabel = label;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (self.cowbellLabel) {
        // 获取实时电量
        float level = [UIDevice currentDevice].batteryLevel;
        int battery = (level < 0) ? 100 : (int)round(level * 100);
        self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.cowbellLabel sizeToFit];

        // 放置在按钮区域内部偏下方 (72x72 bounds 内)
        CGFloat w = self.view.bounds.size.width;
        CGFloat h = self.view.bounds.size.height;
        self.cowbellLabel.center = CGPointMake(w / 2.0, h * 0.72);

        [self.view bringSubviewToFront:self.cowbellLabel];
    }
}

%end

// 动态处理选中/未选中状态下的滤镜切换
%hook CCUIButtonModuleView

- (void)setSelected:(BOOL)selected {
    %orig(selected);

    // 寻找 LowPower 控制器关联的 Label 动态切换 CompositingFilter
    UIResponder *responder = self.nextResponder;
    while (responder && ![responder isKindOfClass:NSClassFromString(@"CCUILowPowerModuleViewController")]) {
        responder = responder.nextResponder;
    }

    if (responder) {
        CCUILowPowerModuleViewController *vc = (CCUILowPowerModuleViewController *)responder;
        if (vc.cowbellLabel) {
            // 按钮开启时（黄色/白色背景）启用 kCAFilterDestOut 镂空；关闭时恢复白色正常字体
            vc.cowbellLabel.layer.compositingFilter = selected ? kCAFilterDestOut : nil;
        }
    }
}

%end
