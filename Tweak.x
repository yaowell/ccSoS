#import <UIKit/UIKit.h>

@interface CCUIToggleViewController : UIViewController
@end

%hook CCUIToggleViewController

- (void)viewWillAppear:(BOOL)animated {

    %orig(animated);

    NSString *path =
        @"/var/mobile/Documents/SimpleCowbell_Test.txt";

    NSString *text =
        [NSString stringWithFormat:
            @"HOOK OK\n"
            @"class=%@\n"
            @"bounds=%@\n"
            @"window=%@\n"
            @"time=%@\n\n",
            NSStringFromClass([self class]),
            NSStringFromCGRect(self.view.bounds),
            self.view.window,
            [NSDate date]
        ];

    NSError *error = nil;

    BOOL success =
        [text writeToFile:path
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:&error];


    /*
     * 不管成功还是失败，
     * 都尝试创建一个最简单的标记文件。
     */

    NSString *flagPath =
        @"/var/mobile/Documents/SimpleCowbell_HOOK.txt";

    NSString *flag =
        @"CCUIToggleViewController viewWillAppear TRIGGERED\n";

    NSError *flagError = nil;

    BOOL flagSuccess =
        [flag writeToFile:flagPath
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:&flagError];


    /*
     * 再尝试追加一个结果文件。
     */

    NSString *result =
        [NSString stringWithFormat:
            @"writeSuccess=%d\n"
            @"writeError=%@\n"
            @"flagSuccess=%d\n"
            @"flagError=%@\n",
            success,
            error,
            flagSuccess,
            flagError
        ];


    [result writeToFile:
        @"/var/mobile/Documents/SimpleCowbell_Result.txt"
             atomically:YES
               encoding:NSUTF8StringEncoding
                  error:nil];
}

%end