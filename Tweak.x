#import <UIKit/UIKit.h>

UIViewController* getTopVC(void) {
    UIWindow *window = nil;
    for(UIWindow *w in [UIApplication sharedApplication].connectedScenes) {
        if([w isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene*)w;
            for(UIWindow *win in ws.windows) {
                if(win.isKeyWindow) window = win;
            }
        }
    }
    UIViewController *vc = window.rootViewController;
    while(vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

%ctor {
    dispatch_async(dispatch_get_main_queue(),^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅注入成功" message:@"SimpleCowbell已加载" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [getTopVC() presentViewController:alert animated:YES completion:nil];
    });
}