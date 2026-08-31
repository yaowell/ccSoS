#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

extern NSString* const kCAFilterDestOut;

@interface CALayer (Private)
@property (nonatomic, retain) NSString *compositingFilter;
@property (nonatomic, assign) BOOL allowsGroupOpacity;
@property (nonatomic, assign) BOOL allowsGroupBlending;
@end

@interface CCUIRoundButton : UIControl
@property (nonatomic, retain) UILabel *cowbellLabel;
@property (nonatomic, assign) BOOL isLowPowerModule;
@end

%hook CCUIRoundButton
%property (nonatomic, retain) UILabel *cowbellLabel;
%property (nonatomic, assign) BOOL isLowPowerModule;

- (instancetype)initWithFrame:(CGRect)frame {
    id orig = %orig;
    if (orig) {
        // 延迟到下一个 Runloop 检查响应链，精准识别低电量模块，不走高频循环
        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIResponder *responder = self; responder; responder = responder.nextResponder) {
                NSString *clsName = NSStringFromClass([responder class]);
                if ([clsName containsString:@"LowPower"]) {
                    self.isLowPowerModule = YES;
                    break;
                }
            }
            
            if (self.isLowPowerModule && !self.cowbellLabel) {
                [UIDevice currentDevice].batteryMonitoringEnabled = YES;

                self.cowbellLabel = [[UILabel alloc] init];
                self.cowbellLabel.textColor = [UIColor whiteColor];
                self.cowbellLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
                
                // 原版精髓：GPU 混合镂空
                self.cowbellLabel.layer.allowsGroupBlending = NO;
                self.cowbellLabel.layer.allowsGroupOpacity = YES;
                self.cowbellLabel.layer.compositingFilter = kCAFilterDestOut;
                
                [self addSubview:self.cowbellLabel];
                [self setNeedsLayout];
            }
        });
    }
    return orig;
}

- (void)layoutSubviews {
    %orig;

    if (self.isLowPowerModule && self.cowbellLabel) {
        float level = [UIDevice currentDevice].batteryLevel;
        int battery = (level < 0) ? 100 : (int)round(level * 100);

        self.cowbellLabel.text = [NSString stringWithFormat:@"%i%%", battery];
        [self.cowbellLabel sizeToFit];

        // 放置在图标底部中央
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        self.cowbellLabel.center = CGPointMake(w / 2.0, h * 0.72);
        
        // 根据当前按钮选中状态动态切换滤镜
        BOOL selected = self.selected;
        self.cowbellLabel.layer.compositingFilter = selected ? kCAFilterDestOut : nil;
    }
}

%end
