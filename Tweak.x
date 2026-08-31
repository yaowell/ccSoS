#import <UIKit/UIKit.h>

%ctor {

    dispatch_async(dispatch_get_main_queue(), ^{

        UIAlertController *alert =
            [UIAlertController
                alertControllerWithTitle:@"SimpleCowbell"
                message:@"Tweak 已经成功加载 SpringBoard"
                preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
            [UIAlertAction
                actionWithTitle:@"OK"
                style:UIAlertActionStyleDefault
                handler:nil]];


        UIWindow *window = nil;

        for (UIWindow *w in
             [UIApplication sharedApplication].windows) {

            if (w.isKeyWindow) {
                window = w;
                break;
            }
        }

        if (!window) {

            window =
                [UIApplication sharedApplication]
                    .windows.firstObject;
        }


        UIViewController *vc =
            window.rootViewController;

        while (vc.presentedViewController) {

            vc =
                vc.presentedViewController;
        }


        if (vc) {

            [vc presentViewController:alert
                             animated:YES
                           completion:nil];
        }

    });
}