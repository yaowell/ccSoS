#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUIRoundButtonViewController : UIViewController
@property (nonatomic, retain) UILabel *cb_percentLabel;
- (void)cb_setupBatteryMonitoring;
- (void)cb_updateBatteryLevel;
@end

%hook CCUIRoundButtonViewController

- (void)viewDidLoad {
    %orig;
    [self cb_setupBatteryMonitoring];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self cb_updateBatteryLevel];
}

%new
- (void)cb_setupBatteryMonitoring {
    // 啟用電量監測
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    // 判斷該按鈕是否屬於「低電量模式」或電池相關模組
    NSString *glyphTitle = [self respondsToSelector:@selector(title)] ? [self performSelector:@selector(title)] : @"";
    NSString *glyphName = [self respondsToSelector:@selector(glyphImageName)] ? [self performSelector:@selector(glyphImageName)] : @"";
    
    // 如果對應到低電量模組
    if ([glyphName containsString:@"battery"] || [glyphTitle containsString:@"Battery"] || [glyphTitle containsString:@"Low Power"] || YES) {
        if (!self.cb_percentLabel) {
            UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
            label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
            label.textColor = [UIColor whiteColor];
            label.userInteractionEnabled = NO;
            
            [self.view addSubview:label];
            self.cb_percentLabel = label;
        }

        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(cb_updateBatteryLevel) 
                                                     name:UIDeviceBatteryLevelDidChangeNotification 
                                                   object:nil];
        
        [self cb_updateBatteryLevel];
    }
}

%new
- (void)cb_updateBatteryLevel {
    float level = [UIDevice currentDevice].batteryLevel;
    if (self.cb_percentLabel) {
        if (level < 0) {
            self.cb_percentLabel.text = @"100%";
        } else {
            self.cb_percentLabel.text = [NSString stringWithFormat:@"%.0f%%", level * 100];
        }
    }
}

%property (nonatomic, retain) UILabel *cb_percentLabel;

%end

%ctor {
    NSLog(@"[SimpleCowbell] Loaded into process: %@", [[NSBundle mainBundle] bundleIdentifier]);
}
