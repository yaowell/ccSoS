#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUILowPowerModeModuleViewController : UIViewController
@property (nonatomic, strong) UILabel *cbPercentLabel;
@end

%hook CCUILowPowerModeModuleViewController
%property (nonatomic, strong) UILabel *cbPercentLabel;

- (void)viewDidLoad {
    %orig;

    self.cbPercentLabel = [[UILabel alloc] init];
    self.cbPercentLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.cbPercentLabel.textAlignment = NSTextAlignmentCenter;
    self.cbPercentLabel.alpha = 1.0f;
    [self.view addSubview:self.cbPercentLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    if (level < 0) level = 1.0f;
    int percent = (int)round(level * 100);

    BOOL lowPowerOn = [NSProcessInfo processInfo].isLowPowerModeEnabled;
    self.cbPercentLabel.text = [NSString stringWithFormat:@"%d%%", percent];
    self.cbPercentLabel.textColor = lowPowerOn ? [UIColor blackColor] : [UIColor whiteColor];
}

- (void)viewWillLayoutSubviews {
    %orig;

    if (self.cbPercentLabel) {
        [self.cbPercentLabel sizeToFit];
        CGFloat w = self.view.bounds.size.width;
        CGFloat h = self.view.bounds.size.height;
        self.cbPercentLabel.frame = CGRectMake((w - self.cbPercentLabel.bounds.size.width) / 2.0, h * 0.70, self.cbPercentLabel.bounds.size.width, self.cbPercentLabel.bounds.size.height);
    }
}

- (void)refreshState {
    %orig;

    BOOL lowPowerOn = [NSProcessInfo processInfo].isLowPowerModeEnabled;
    self.cbPercentLabel.textColor = lowPowerOn ? [UIColor blackColor] : [UIColor whiteColor];
}

%end