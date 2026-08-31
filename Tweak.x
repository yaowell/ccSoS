#import <UIKit/UIKit.h>

@interface CCUIContentModuleContainerView : UIView
@end

static void collectHierarchy(UIView *view, int depth, NSMutableString *result) {
    if (!view || depth > 3) return;
    
    for (int i = 0; i < depth; i++) [result appendString:@"  --"];
    [result appendFormat:@"%@ (%.0f,%.0f)\n", 
            NSStringFromClass([view class]), 
            view.frame.size.width, 
            view.frame.size.height];

    for (UIView *subview in view.subviews) {
        collectHierarchy(subview, depth + 1, result);
    }
}

static BOOL hasShownAlert = NO;

%hook CCUIContentModuleContainerView

- (void)layoutSubviews {
    %orig;
    
    NSString *desc = [self description];
    if ((!hasShownAlert) && ([desc containsString:@"LowPower"] || [desc containsString:@"lowpower"])) {
        hasShownAlert = YES;
        
        NSMutableString *hierarchyText = [NSMutableString string];
        collectHierarchy(self, 0, hierarchyText);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *window = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    window = ((UIWindowScene *)scene).windows.firstObject;
                    break;
                }
            }
            if (!window) window = [UIApplication sharedApplication].windows.firstObject;

            UIViewController *rootVC = window.rootViewController;
            while (rootVC.presentedViewController) {
                rootVC = rootVC.presentedViewController;
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"LowPower Hierarchy" 
                                                                           message:hierarchyText 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                hasShownAlert = NO;
            }]];
            [rootVC presentViewController:alert animated:YES completion:nil];
        });
    }
}

%end
