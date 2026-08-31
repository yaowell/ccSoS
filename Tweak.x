#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

extern NSString* const kCAFilterDestOut;

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUILowPowerModuleViewController : UIViewController
@property (nonatomic, retain) UILabel *cowbellLabel;
@property (nonatomic, assign, readonly) BOOL selected;
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
        label.userInteractionEnabled = NO; // 防止拦截按钮点击事件导致崩溃

        // 默认配置 GPU 镂空属性
        label.layer.allowsGroupBlending = NO;
        label.layer.allowsGroupOpacity = YES;

        [self.view addSubview:label];
        self.cowbellLabel = label;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (!self.cowbellLabel) return;

    // 1. 获取实时电量
    float level = [UIDevice currentDevice].batteryLevel;
    int battery = (level < 0) ? 100 : (int)round(level * 100);
    self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
    [self.cowbellLabel sizeToFit];

    // 2. 布局：居中偏下
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    if (w > 0 && h > 0) {
        self.cowbellLabel.center = CGPointMake(w / 2.0, h * 0.72);
    }

    // 3. 安全获取选中状态（防止 Unrecognized Selector 崩溃）
    BOOL isSelected = NO;
    if ([self respondsToSelector:@selector(isSelected)]) {
        isSelected = [self selected];
    } else if ([self respondsToSelector:@selector(isExpanded)]) {
        isSelected = ((BOOL (*)(id, SEL))objc_msgSend)(self, @selector(isExpanded));
    }

    // 4. 根据选中状态切换滤镜（开启低电量时用镂空，关闭时用原色）
    self.cowbellLabel.layer.compositingFilter = isSelected ? kCAFilterDestOut : nil;

    [self.view bringSubviewToFront:self.cowbellLabel];
}

%end
