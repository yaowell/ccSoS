#import <UIKit/UIKit.h>

// 递归打印视图树与 Frame
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
    // 只要判断模块说明包含 LowPower，就递归打印整个容器内部
    if ([self.description containsString:@"LowPower"] || [self.description containsString:@"lowpower"]) {
        NSLog(@"[Cowbell_Debug] === Found LowPower Container ===");
        printViewHierarchy(self, 0);
    }
}

%end
