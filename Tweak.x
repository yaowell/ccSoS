#import <UIKit/UIKit.h>

%hook CCUICAPackageView

- (void)didMoveToWindow {
    %orig;

    NSLog(@"[CBDEBUG] CCUICAPackageView didMoveToWindow: %@ | window=%@ | super=%@",
          self,
          self.window,
          self.superview);
}

- (void)layoutSubviews {
    %orig;

    NSLog(@"[CBDEBUG] CCUICAPackageView layout: %@ | frame=%@ | super=%@",
          self,
          NSStringFromCGRect(self.frame),
          self.superview);
}

- (void)setHidden:(BOOL)hidden {
    NSLog(@"[CBDEBUG] CCUICAPackageView setHidden=%d | %@",
          hidden,
          self);

    %orig;
}

- (void)setAlpha:(CGFloat)alpha {
    NSLog(@"[CBDEBUG] CCUICAPackageView alpha=%.2f | %@",
          alpha,
          self);

    %orig;
}

%end