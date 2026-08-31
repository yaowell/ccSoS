#import <UIKit/UIKit.h>

@interface CCUIToggleViewController : UIViewController
@end

%hook CCUIToggleViewController

- (void)viewWillAppear:(BOOL)animated {

    %orig(animated);

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

    NSString *path =
        @"/var/mobile/Documents/SimpleCowbell_Test.txt";

    [text writeToFile:path
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];
}

%end