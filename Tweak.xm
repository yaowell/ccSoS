#import <UIKit/UIKit.h>

@interface CCUIRoundButton : UIView
@property (nonatomic, strong) UIImageView *glyphImageView;
- (void)cc_addBatteryLabel;
@end

%hook CCUIRoundButton

- (void)layoutSubviews {
    %orig;
    [self cc_addBatteryLabel];
}

%new
- (void)cc_addBatteryLabel {
    // 1. 取得 Glyph 視圖
    UIImageView *glyph = nil;
    if ([self respondsToSelector:@selector(glyphImageView)]) {
        glyph = [self glyphImageView];
    }
    
    if (!glyph) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                glyph = (UIImageView *)subview;
                break;
            }
        }
    }

    // 2. 特徵識別（判定是不是低電量模組）
    BOOL isBatteryModule = NO;
    
    // 途徑 A：檢查圖片 Accessibility 標籤
    if (glyph && glyph.image) {
        NSString *imageName = glyph.image.accessibilityIdentifier ?: @"";
        if ([imageName.lowercaseString containsString:@"battery"] || [imageName.lowercaseString containsString:@"lowpower"]) {
            isBatteryModule = YES;
        }
    }

    // 途徑 B：沿著 響應鏈 (NextResponder) 向上找類名
    if (!isBatteryModule) {
        UIResponder *responder = self.nextResponder;
        while (responder) {
            NSString *clsName = NSStringFromClass([responder class]);
            if ([clsName containsString:@"LowPower"]) {
                isBatteryModule = YES;
                break;
            }
            responder = responder.nextResponder;
        }
    }

    // 非低電量模組直接跳過
    if (!isBatteryModule) return;

    // 3. 繪製 Label
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    if (width <= 0 || height <= 0) return;

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    UILabel *label = (UILabel *)[self viewWithTag:99999];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 99999;
        label.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        [self addSubview:label];
    }

    // 絕對定位放置在圓形底部
    label.frame = CGRectMake(0, height - 15, width, 12);

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"%";
    }

    BOOL isLPMEnabled = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLPMEnabled ? [UIColor blackColor] : [UIColor whiteColor];

    [self bringSubviewToFront:label];
}

%end
