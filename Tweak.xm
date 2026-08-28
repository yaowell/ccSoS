#import <UIKit/UIKit.h>

@interface CCUIRoundButtonViewController : UIViewController
@property (nonatomic, strong) UIView *buttonView;
- (void)updateCowbellPercentLabel;
@end

@interface CCUILowPowerModuleViewController : CCUIRoundButtonViewController
@end

%hook CCUIRoundButtonViewController

- (void)viewDidLayoutSubviews {
    %orig;
    
    // Only target the Low Power module
    if ([self isKindOfClass:NSClassFromString(@"CCUILowPowerModuleViewController")]) {
        [self updateCowbellPercentLabel];
    }
}

%new
- (void)updateCowbellPercentLabel {
    UIView *container = self.buttonView ? self.buttonView : self.view;
    if (!container) return;

    // Retrieve battery percentage
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    int percent = (level >= 0) ? (int)round(level * 100.0) : 0;

    UILabel *label = (UILabel *)[container viewWithTag:88888];
    if (!label) {
        label = [[UILabel alloc] init];
        label.tag = 88888;
        label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        
        [container addSubview:label];
        
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [label.centerYAnchor constraintEqualToAnchor:container.centerYAnchor constant:10],
            [label.widthAnchor constraintEqualToAnchor:container.widthAnchor],
            [label.heightAnchor constraintEqualToConstant:14]
        ]];
    }

    if (percent > 0) {
        label.text = [NSString stringWithFormat:@"%d%%", percent];
    } else {
        label.text = @"";
    }

    BOOL isLowPower = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    label.textColor = isLowPower ? [UIColor blackColor] : [UIColor whiteColor];

    [container bringSubviewToFront:label];
}

%end
