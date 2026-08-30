#import <UIKit/UIKit.h>

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

static void CBWriteLog(NSString *text) {
    NSString *path = @"/var/mobile/Documents/CBDEBUG.txt";

    NSString *old =
        [NSString stringWithContentsOfFile:path
                                  encoding:NSUTF8StringEncoding
                                     error:nil];

    if (!old) {
        old = @"";
    }

    NSString *newText =
        [old stringByAppendingFormat:@"%@\n", text];

    [newText writeToFile:path
              atomically:NO
                encoding:NSUTF8StringEncoding
                   error:nil];
}

%hook CCUICAPackageView

- (void)didMoveToWindow {
    %orig;

    UIView *v = (UIView *)self;

    CBWriteLog([NSString stringWithFormat:
        @"\n===== didMoveToWindow =====\n"
         "class=%@\n"
         "window=%@\n"
         "superview=%@\n"
         "frame=%@\n"
         "hidden=%d\n"
         "alpha=%.2f",
        NSStringFromClass([v class]),
        v.window,
        v.superview,
        NSStringFromCGRect(v.frame),
        v.hidden,
        v.alpha
    ]);
}

- (void)layoutSubviews {
    %orig;

    UIView *v = (UIView *)self;

    CBWriteLog([NSString stringWithFormat:
        @"\n===== layoutSubviews =====\n"
         "class=%@\n"
         "frame=%@\n"
         "hidden=%d\n"
         "alpha=%.2f\n"
         "superview=%@",
        NSStringFromClass([v class]),
        NSStringFromCGRect(v.frame),
        v.hidden,
        v.alpha,
        v.superview
    ]);
}

- (void)setHidden:(BOOL)hidden {

    UIView *v = (UIView *)self;

    CBWriteLog([NSString stringWithFormat:
        @"===== setHidden ===== class=%@ hidden=%d",
        NSStringFromClass([v class]),
        hidden
    ]);

    %orig;
}

- (void)setAlpha:(CGFloat)alpha {

    UIView *v = (UIView *)self;

    CBWriteLog([NSString stringWithFormat:
        @"===== setAlpha ===== class=%@ alpha=%.2f",
        NSStringFromClass([v class]),
        alpha
    ]);

    %orig;
}

%end