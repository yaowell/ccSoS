#import <UIKit/UIKit.h>

%ctor {
    dispatch_async(dispatch_get_main_queue(),^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅插件注入成功" message:@"SimpleCowbell已经被ElleKit加载" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:alert animated:YES completion:nil];
    });
}