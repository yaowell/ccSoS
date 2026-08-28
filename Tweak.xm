#import <UIKit/UIKit.h>

@interface CCUILowPowerModuleViewController : UIViewController
- (void)updateCowbellPercent;
@end

%hook CCUILowPowerModuleViewController

- (void)viewDidLoad {
    %orig;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellPercent)
                                                 name:UIDeviceBatteryLevelDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCowbellPercent)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self updateCowbellPercent];
}

%new
- (void)updateCowbellPercent {
    UIView *mainView = self.view;
    if (!mainView) return;

    CGFloat width = mainView.bounds.size.width;
    CGFloat height = mainView.bounds.size.height;
    if (width <= 0 || height <= 0) return;

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    UILabel *label = (UILabel *)[mainView viewWithTag:6666];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 6666;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        [mainView addSubview:label];
    }

    label.frame = CGRectMake(0, height - 18, width, 14);

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"--%";
    }

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    [mainView bringSubviewToFront:label];
}

%end
