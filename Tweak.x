#import <UIKit/UIKit.h>

// 1. 补全类接口声明，告知 Clang 它继承自 UIView
@interface CCUIContentModuleContainerView : UIView
@end

// 2. 递归打印视图树与 Frame
static void printViewHierarchy(UIView *view, int depth) {
    if (!view) return;
    NSMutableString *indent = [NSMutableString string];
    for (int i = 0; i < depth; i++) [indent appendString:@"  |"];
    
    NSLog(@"[Cowbell_Debug]%@ %@ (Frame: %@, Hidden: %d, Alpha: %.2f)", 
          indent, 
          NSStringFromClass([view class]), 
          NSStringFromCGRect(view.frame), 
          view.hidden, 
          view.alpha);

    for (UIView *subview in view.subviews) {
        printViewHierarchy(subview, depth + 1);
    }
}

%hook CCUIContentModuleContainerView

- (void)layoutSubviews {
    %orig;
    
    // 使用 description 检查是否为低电量模块
    NSString *desc = [self description];
    if ([desc containsString:@"LowPower"] || [desc containsString:@"lowpower"]) {
        NSLog(@"[Cowbell_Debug] === Found LowPower Container ===");
        printViewHierarchy(self, 0);
    }
}

%end
