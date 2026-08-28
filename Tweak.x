#import <UIKit/UIKit.h>

@interface CCUIControlCenterViewController : UIViewController
- (void)printSubviews:(UIView *)v depth:(int)d;
@end

%hook CCUIControlCenterViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSLog(@"[DebugTweak] ===== 【控制中心視圖樹開始打印】 =====");
    [self printSubviews:self.view depth:0];
    NSLog(@"[DebugTweak] ===== 【打印結束】 =====");
}

%new
- (void)printSubviews:(UIView *)v depth:(int)d {
    NSMutableString *pad = [NSMutableString string];
    for (int i = 0; i < d; i++) {
        [pad appendString:@"  "];
    }
    
    // 輸出當前 View 的類名
    NSLog(@"[DebugTweak] %@%@", pad, NSStringFromClass([v class]));
    
    for (UIView *sv in v.subviews) {
        [self printSubviews:sv depth:d + 1];
    }
}

%end

%ctor {
    NSLog(@"[DebugTweak] SpringBoard injected OK");
}
