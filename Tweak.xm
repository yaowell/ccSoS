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
    // 1. 取得按鈕內部的圖標（Glyph）
    UIImageView *glyph = nil;
    if ([self respondsToSelector:@selector(glyphImageView)]) {
        glyph = [self glyphImageView];
    }
    
    // 如果找不到 Glyph，遍歷子視圖尋找 UIImageView
    if (!glyph) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                glyph = (UIImageView *)subview;
                break;
            }
        }
    }

    // 2. 特徵識別：檢查圖標名稱或 AccessibilityIdentifier 是不是電池（LowPower / Battery）
    BOOL isBatteryModule = NO;
    if (glyph && glyph.image) {
        NSString *imageName = glyph.image.accessibilityIdentifier ?: @"";
        // 系統低電量圖紙通常包含 battery, lowpower 或 battery.controlcenter
        if ([imageName.lowercaseString containsString:@"battery"] || [imageName.lowercaseString containsString:@"lowpower"]) {
            isBatteryModule = YES;
        }
    }

    // 備用識別：如果無法讀取圖片名稱，檢查父層 Bundle/ViewController 類名
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

    // 如果不是低電量按鈕，直接退出（不干擾手電筒等其他按鈕）
    if (!isBatteryModule) return;

    // 3. 開始繪製電量百分比 Label
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

    // 強制定位在按鈕圓形的底部偏中位置
    label.frame = CGRectMake(0, height - 16, width, 12);

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"%";
    }

    BOOL isLPMEnabled = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLPMEnabled ? [UIColor blackColor] : [UIColor whiteColor];

    // 確保浮在最頂層
    [self bringSubviewToFront:label];
}

%end
