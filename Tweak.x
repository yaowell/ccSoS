#import <UIKit/UIKit.h>

@class CCUIBatteryView;

@interface CCUIBatteryView ()
@property (nonatomic, strong) UILabel *sb_percentLabel;
@end

%hook CCUIBatteryView

- (instancetype)initWithFrame:(CGRect)frame {
    %orig;
    UIDevice *dev = [UIDevice currentDevice];
    dev.batteryMonitoringEnabled = YES;
    return self;
}

- (void)layoutSubviews {
    %orig;

    UILabel *percentLabel = self.sb_percentLabel;
    if (!percentLabel) {
        percentLabel = [[UILabel alloc] init];
        percentLabel.font = [UIFont boldSystemFontOfSize:9.0];
        percentLabel.textColor = [UIColor whiteColor];
        percentLabel.textAlignment = NSTextAlignmentCenter;
        percentLabel.backgroundColor = [UIColor clearColor];
        self.sb_percentLabel = percentLabel;
        [self addSubview:percentLabel];
    }

    UIDevice *device = [UIDevice currentDevice];
    float level = device.batteryLevel;
    int percent = (int)(level * 100.0f);
    if(level >= 0){
        percentLabel.text = [NSString stringWithFormat:@"%d%%", percent];
    }else{
        percentLabel.text = @"";
    }

    CGFloat insetX = 2.0f;
    CGFloat insetY = 1.0f;
    percentLabel.frame = CGRectMake(insetX, insetY,
                                    CGRectGetWidth(self.bounds)-insetX*2,
                                    CGRectGetHeight(self.bounds)-insetY*2);
}

- (void)dealloc {
    %orig;
    self.sb_percentLabel = nil;
}

%end