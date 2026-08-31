#import <UIKit/UIKit.h>

@interface CCUIToggleViewController : UIViewController
@property (nonatomic, retain) id module;
@end

%hook CCUIToggleViewController

- (void)viewDidLoad {
    %orig;

    NSLog(@"[SimpleCowbell] ===== viewDidLoad =====");
    NSLog(@"[SimpleCowbell] class = %@", NSStringFromClass([self class]));
    NSLog(@"[SimpleCowbell] module = %@", self.module);

    if (self.module) {
        NSLog(@"[SimpleCowbell] module class = %@",
              NSStringFromClass([self.module class]));
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);

    NSLog(@"[SimpleCowbell] ===== viewWillAppear =====");
    NSLog(@"[SimpleCowbell] class = %@", NSStringFromClass([self class]));
    NSLog(@"[SimpleCowbell] module = %@", self.module);

    if (self.module) {
        NSLog(@"[SimpleCowbell] module class = %@",
              NSStringFromClass([self.module class]));
    }
}

- (void)refreshState {
    NSLog(@"[SimpleCowbell] ===== refreshState =====");
    NSLog(@"[SimpleCowbell] module = %@", self.module);

    if (self.module) {
        NSLog(@"[SimpleCowbell] module class = %@",
              NSStringFromClass([self.module class]));
    }

    %orig;
}

%end