#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

%hook CCUICAPackageView

- (void)didMoveToWindow {
    %orig;

    UIView *view = (UIView *)self;

    NSLog(@"[CBDEBUG] ===== didMoveToWindow =====");
    NSLog(@"[CBDEBUG] class=%@", NSStringFromClass([view class]));
    NSLog(@"[CBDEBUG] window=%@", view.window);
    NSLog(@"[CBDEBUG] superview=%@", view.superview);
}


- (void)layoutSubviews {
    %orig;

    UIView *view = (UIView *)self;

    NSLog(@"[CBDEBUG] ===== layoutSubviews =====");
    NSLog(@"[CBDEBUG] class=%@", NSStringFromClass([view class]));
    NSLog(@"[CBDEBUG] frame=%@", NSStringFromCGRect(view.frame));
    NSLog(@"[CBDEBUG] hidden=%d alpha=%.2f",
          view.hidden,
          view.alpha);
}


- (void)setHidden:(BOOL)hidden {

    UIView *view = (UIView *)self;

    NSLog(@"[CBDEBUG] ===== setHidden =====");
    NSLog(@"[CBDEBUG] class=%@", NSStringFromClass([view class]));
    NSLog(@"[CBDEBUG] hidden=%d", hidden);

    %orig;
}


- (void)setAlpha:(CGFloat)alpha {

    UIView *view = (UIView *)self;

    NSLog(@"[CBDEBUG] ===== setAlpha =====");
    NSLog(@"[CBDEBUG] class=%@", NSStringFromClass([view class]));
    NSLog(@"[CBDEBUG] alpha=%.2f", alpha);

    %orig;
}

%end