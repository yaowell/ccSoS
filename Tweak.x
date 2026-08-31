#import <UIKit/UIKit.h>

@interface CCUIToggleViewController : UIViewController
@end

%hook CCUIToggleViewController

- (void)viewDidAppear:(BOOL)animated {

    %orig(animated);

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"SimpleCowbell"
            message:@"CCUIToggleViewController viewDidAppear 被触发"
            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault
            handler:nil]];

    UIViewController *vc = self;

    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }

    if (vc) {
        [vc presentViewController:alert
                         animated:YES
                       completion:nil];
    }
}

%end