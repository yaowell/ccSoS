#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIBatteryStatusItemView : UIView
@property (nonatomic, strong) UILabel *cbPercentLabel;
- (void)cb_updateText;
@end

%hook CCUIBatteryStatusItemView

%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)didMoveToSuperview {
    %orig;
    if(!self.cbPercentLabel){
        UILabel *lab = [[UILabel alloc] init];
        lab.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        lab.textColor = [UIColor whiteColor];
        lab.frame = CGRectMake(-24, 1, 22, 13);
        lab.textAlignment = NSTextAlignmentRight;
        self.cbPercentLabel = lab;
        [self addSubview:lab];
    }
    [self cb_updateText];
}

- (void)cb_updateText {
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (int)(level*100);
    self.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%",percent];
}

- (void)layoutSubviews {
    %orig;
    [self cb_updateText];
}

%end