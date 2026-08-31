#import <UIKit/UIKit.h>

@interface CCUIToggleViewController : UIViewController
@end

%hook CCUIToggleViewController

- (void)viewWillAppear:(BOOL)animated {

    NSLog(@"[SimpleCowbell] ===== CCUIToggleViewController viewWillAppear =====");

    %orig(animated);

    NSLog(@"[SimpleCowbell] view = %@", self.view);
    NSLog(@"[SimpleCowbell] bounds = %@", NSStringFromCGRect(self.view.bounds));
    NSLog(@"[SimpleCowbell] window = %@", self.view.window);
}

%end