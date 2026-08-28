#import <UIKit/UIKit.h>

@interface CCUIBatteryView : UIView
- (void)cb_setupBatteryMonitoring;
@end

%hook CCUIBatteryView

- (instancetype)initWithFrame:(CGRect)frame {
    id result = %orig;
    if (result) {
        [self cb_setupBatteryMonitoring];
    }
    return result;
}

%new
- (void)cb_setupBatteryMonitoring {
    // 你的程式碼 logic
}

%end
