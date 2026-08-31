#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <unistd.h>

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end


static NSString *CBLogPath(void) {
    return @"/var/mobile/Media/Downloads/CBDEBUG.txt";
}


static void CBWriteLog(NSString *format, ...) {

    NSString *path = CBLogPath();

    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);


    NSString *time =
        [[NSDate date] description];

    NSString *line =
        [NSString stringWithFormat:
            @"\n[%@] PID:%d %@\n",
            time,
            getpid(),
            message];


    /*
     * 防止日志无限变大
     */
    NSDictionary *attrs =
        [[NSFileManager defaultManager]
            attributesOfItemAtPath:path
                             error:nil];

    unsigned long long fileSize =
        [attrs fileSize];

    if (fileSize > 300 * 1024) {
        [[NSFileManager defaultManager]
            removeItemAtPath:path
                       error:nil];
    }


    NSString *old =
        [NSString stringWithContentsOfFile:path
                                  encoding:NSUTF8StringEncoding
                                     error:nil];

    if (!old) {
        old = @"";
    }


    NSString *result =
        [old stringByAppendingString:line];


    [result writeToFile:path
             atomically:YES
               encoding:NSUTF8StringEncoding
                  error:nil];
}


/*
 * 获取整个父级层级
 */
static NSString *CBHierarchy(UIView *view) {

    NSMutableString *result =
        [NSMutableString string];

    UIView *current = view;

    int level = 0;

    while (current && level < 12) {

        [result appendFormat:
            @"\n  [%d] %@ frame=%@ hidden=%d alpha=%.2f",
            level,
            NSStringFromClass([current class]),
            NSStringFromCGRect(current.frame),
            current.hidden,
            current.alpha
        ];

        current = current.superview;
        level++;
    }

    return result;
}


/*
 * tweak 加载测试
 */
%ctor {

    CBWriteLog(
        @"==============================\n"
         "SimpleCowbell DEBUG START\n"
         "Process=%@\n"
         "==============================",
        [[NSProcessInfo processInfo] processName]
    );
}


%hook CCUICAPackageView


- (void)didMoveToWindow {

    %orig;

    UIView *view = (UIView *)self;

    CBWriteLog(
        @"\n========== didMoveToWindow ==========\n"
         "packageName=%@\n"
         "window=%@\n"
         "hierarchy:%@",
        self.packageName,
        view.window,
        CBHierarchy(view)
    );
}


- (void)layoutSubviews {

    %orig;

    UIView *view = (UIView *)self;

    CBWriteLog(
        @"\n========== layoutSubviews ==========\n"
         "packageName=%@\n"
         "frame=%@\n"
         "hidden=%d\n"
         "alpha=%.2f\n"
         "hierarchy:%@",
        self.packageName,
        NSStringFromCGRect(view.frame),
        view.hidden,
        view.alpha,
        CBHierarchy(view)
    );
}


- (void)setHidden:(BOOL)hidden {

    UIView *view = (UIView *)self;

    CBWriteLog(
        @"========== setHidden ==========\n"
         "packageName=%@\n"
         "old=%d new=%d",
        self.packageName,
        view.hidden,
        hidden
    );

    %orig;
}


- (void)setAlpha:(CGFloat)alpha {

    UIView *view = (UIView *)self;

    CBWriteLog(
        @"========== setAlpha ==========\n"
         "packageName=%@\n"
         "old=%.2f new=%.2f",
        self.packageName,
        view.alpha,
        alpha
    );

    %orig;
}


%end