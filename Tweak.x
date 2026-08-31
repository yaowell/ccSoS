#import <UIKit/UIKit.h>

%ctor {

    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *window = nil;

        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            if (windowScene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            for (UIWindow *w in windowScene.windows) {

                if (w.isKeyWindow) {
                    window = w;
                    break;
                }
            }

            if (window) {
                break;
            }
        }


        if (!window) {
            return;
        }


        UIViewController *vc =
            window.rootViewController;


        if (!vc) {
            return;
        }


        while (vc.presentedViewController) {

            vc =
                vc.presentedViewController;
        }


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


        [vc presentViewController:alert
                         animated:YES
                       completion:nil];

    });
}