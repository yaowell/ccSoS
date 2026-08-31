#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <unistd.h>

@interface CCUICAPackageView : UIView
@property (nonatomic, copy) NSString *packageName;
@end

static void CBWriteDebug(NSString *text) {

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{

        NSString *path =
            @"/var/mobile/Media/Downloads/CBDEBUG.txt";

        NSString *line =
            [NSString stringWithFormat:
                @"[%@] PID:%d %@\n",
                [NSDate date],
                getpid(),
                text];

        NSFileManager *fm =
            [NSFileManager defaultManager];

        NSDictionary *attr =
            [fm attributesOfItemAtPath:path error:nil];

        unsigned long long size =
            [attr fileSize];

        /*
         * 超过 100 KB 就清空。
         */
        if (size > 100 * 1024) {
            [fm removeItemAtPath:path error:nil];
        }

        NSFileHandle *file =
            [NSFileHandle fileHandleForWritingAtPath:path];

        if (!file) {

            [line writeToFile:path
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:nil];

            return;
        }

        @try {
            [file seekToEndOfFile];

            [file writeData:
                [line dataUsingEncoding:
                    NSUTF8StringEncoding]];

            [file closeFile];

        } @catch (__unused NSException *exception) {
            [file closeFile];
        }
    });
}


%hook CCUICAPackageView

- (void)didMoveToWindow {

    %orig;

    UIView *view = (UIView *)self;

    NSString *className =
        NSStringFromClass([view class]);

    NSString *package =
        self.packageName ?: @"";

    BOOL hasWindow =
        (view.window != nil);

    NSString *message =
        [NSString stringWithFormat:
            @"CCUICAPackageView didMoveToWindow | "
             "class=%@ | package=%@ | window=%d",
            className,
            package,
            hasWindow];

    CBWriteDebug(message);
}

%end