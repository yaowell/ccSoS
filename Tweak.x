#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kBatteryViewKey;

@interface CCUILowPowerModeModuleViewController : UIViewController
@end

@interface CBCustomBatteryPercentView : UIView
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, assign) int cachedPercent;
@property (nonatomic, assign) BOOL cachedLowPower;
@end

@implementation CBCustomBatteryPercentView

- (instancetype)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]){
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.cachedPercent = -1;
        self.cachedLowPower = NO;
        
        _percentLabel = [[UILabel alloc] init];
        _percentLabel.textAlignment = NSTextAlignmentCenter;
        _percentLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        [self addSubview:_percentLabel];
    }
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if(!self.window) return;
    
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel;
    if(level < 0) level = 1.0f;
    self.cachedPercent = (int)round(level * 100);
    self.percentLabel.text = [NSString stringWithFormat:@"%d%%",self.cachedPercent];
    
    BOOL state = [NSProcessInfo processInfo].isLowPowerModeEnabled;
    self.cachedLowPower = state;
    self.percentLabel.textColor = state ? [UIColor blackColor] : [UIColor whiteColor];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL state = [NSProcessInfo processInfo].isLowPowerModeEnabled;
    if(self.cachedLowPower != state){
        self.cachedLowPower = state;
        self.percentLabel.textColor = state ? [UIColor blackColor] : [UIColor whiteColor];
    }
    
    [self.percentLabel sizeToFit];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    self.percentLabel.frame = CGRectMake((w - self.percentLabel.bounds.size.width)/2, h*0.70, self.percentLabel.bounds.size.width, self.percentLabel.bounds.size.height);
}

@end

%hook CCUILowPowerModeModuleViewController

- (void)viewDidLayoutSubviews {
    %orig;
    
    CBCustomBatteryPercentView *pView = objc_getAssociatedObject(self, &kBatteryViewKey);
    if(!pView){
        pView = [[CBCustomBatteryPercentView alloc] initWithFrame:self.view.bounds];
        pView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:pView];
        objc_setAssociatedObject(self, &kBatteryViewKey, pView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    pView.frame = self.view.bounds;
}

%end