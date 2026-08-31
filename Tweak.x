#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface CCUICAPackageView : UIView

@property (nonatomic, copy) NSString *packageName;

@end


@interface SBControlCenterController : UIViewController

- (void)presentAnimated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated;

@end


#pragma mark -
#pragma mark Tracking

static NSMutableArray *SCTrackedCAPackages;
static BOOL SCControlCenterVisible;
static BOOL SCShowingResult;


static void SCAddPackageView(CCUICAPackageView *view) {

    if (!view) {
        return;
    }

    @synchronized (SCTrackedCAPackages) {

        if (![SCTrackedCAPackages containsObject:view]) {

            [SCTrackedCAPackages addObject:view];
        }
    }
}


static NSString *SCPackageName(CCUICAPackageView *view) {

    NSString *name = nil;

    @try {

        if ([view respondsToSelector:@selector(packageName)]) {

            name = [view valueForKey:@"packageName"];
        }

    } @catch (__unused NSException *exception) {
    }

    if (!name.length) {
        name = @"<nil>";
    }

    return name;
}


static NSString *SCClassName(id object) {

    if (!object) {
        return @"<nil>";
    }

    return NSStringFromClass([object class]);
}


static void SCShowResult(void) {

    if (!SCControlCenterVisible) {
        return;
    }

    if (SCShowingResult) {
        return;
    }

    SCShowingResult = YES;


    NSMutableString *info =
        [NSMutableString string];

    [info appendString:
        @"===== CCUICAPackageView =====\n\n"
    ];


    NSArray *packages = nil;

    @synchronized (SCTrackedCAPackages) {

        packages =
            [SCTrackedCAPackages copy];
    }


    NSInteger count = 0;


    for (CCUICAPackageView *view in packages) {

        /*
         * 只关心目前还存在并且进入 Window 的 View。
         */

        if (!view) {
            continue;
        }

        if (!view.window) {
            continue;
        }


        count++;


        [info appendFormat:
            @"[%ld]\n",
            (long)count
        ];


        [info appendFormat:
            @"class = %@\n",
            SCClassName(view)
        ];


        [info appendFormat:
            @"package = %@\n",
            SCPackageName(view)
        ];


        [info appendFormat:
            @"frame = %@\n",
            NSStringFromCGRect(view.frame)
        ];


        [info appendFormat:
            @"bounds = %@\n",
            NSStringFromCGRect(view.bounds)
        ];


        /*
         * Superview 链
         */

        [info appendString:
            @"superview:\n"
        ];


        UIView *superview =
            view.superview;


        NSInteger level = 0;


        while (superview && level < 6) {

            [info appendFormat:
                @"  [%ld] %@\n",
                (long)level,
                SCClassName(superview)
            ];


            superview =
                superview.superview;

            level++;
        }


        /*
         * 直接子 View
         */

        [info appendString:
            @"subviews:\n"
        ];


        NSInteger index = 0;


        for (UIView *subview in view.subviews) {

            [info appendFormat:
                @"  [%ld] %@ frame=%@\n",
                (long)index,
                SCClassName(subview),
                NSStringFromCGRect(subview.frame)
            ];


            index++;
        }


        [info appendString:
            @"\n"
        ];
    }


    if (count == 0) {

        [info appendString:
            @"没有找到进入 Window 的 "
            @"CCUICAPackageView。\n"
        ];
    }


    /*
     * 最多显示一段合理长度，
     * 防止 UIAlert 过长导致无法阅读。
     */

    if (info.length > 7000) {

        [info deleteCharactersInRange:
            NSMakeRange(
                7000,
                info.length - 7000
            )
        ];

        [info appendString:
            @"\n\n[内容过长，已截断]"
        ];
    }


    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *window = nil;


        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }


            UIWindowScene *windowScene =
                (UIWindowScene *)scene;


            if (windowScene.activationState !=
                UISceneActivationStateForegroundActive) {

                continue;
            }


            for (UIWindow *candidate in
                 windowScene.windows) {

                if (candidate.isKeyWindow) {

                    window = candidate;
                    break;
                }
            }


            if (window) {
                break;
            }
        }


        if (!window) {

            SCShowingResult = NO;
            return;
        }


        UIViewController *vc =
            window.rootViewController;


        if (!vc) {

            SCShowingResult = NO;
            return;
        }


        while (vc.presentedViewController) {

            vc =
                vc.presentedViewController;
        }


        UIAlertController *alert =
            [UIAlertController
                alertControllerWithTitle:
                    @"CC Package 扫描结果"
                message:info
                preferredStyle:
                    UIAlertControllerStyleAlert];


        [alert addAction:
            [UIAlertAction
                actionWithTitle:@"OK"
                style:UIAlertActionStyleDefault
                handler:^(__unused UIAlertAction *action) {

                    SCShowingResult = NO;
                }
            ]
        ];


        [vc presentViewController:
                alert
                         animated:YES
                       completion:nil];
    });
}


#pragma mark -
#pragma mark CCUICAPackageView

%hook CCUICAPackageView


- (instancetype)initWithFrame:(CGRect)frame {

    CCUICAPackageView *result =
        %orig(frame);


    SCAddPackageView(result);


    return result;
}


- (instancetype)initWithCoder:(NSCoder *)coder {

    CCUICAPackageView *result =
        %orig(coder);


    SCAddPackageView(result);


    return result;
}


- (void)didMoveToWindow {

    %orig;


    SCAddPackageView(self);


    /*
     * 只有控制中心已经打开时，
     * 才把这个新进入 Window 的实例视为候选对象。
     */

    if (SCControlCenterVisible &&
        self.window) {

        /*
         * 给系统一点时间完成布局。
         */

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.5 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

                if (SCControlCenterVisible) {

                    SCShowResult();
                }
            }
        );
    }
}


- (void)layoutSubviews {

    %orig;


    SCAddPackageView(self);
}


%end


#pragma mark -
#pragma mark Control Center

%hook SBControlCenterController


- (void)presentAnimated:(BOOL)animated {

    SCControlCenterVisible = YES;
    SCShowingResult = NO;


    %orig(animated);


    /*
     * 第一次等待。
     *
     * 控制中心刚出现的时候，
     * 一部分 CAPackageView 可能还没有完成布局。
     */

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.8 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

            if (SCControlCenterVisible) {

                SCShowResult();
            }
        }
    );
}


- (void)dismissAnimated:(BOOL)animated {

    SCControlCenterVisible = NO;


    %orig(animated);
}


%end


#pragma mark -
#pragma mark Constructor

%ctor {

    SCTrackedCAPackages =
        [NSMutableArray array];

    SCControlCenterVisible = NO;
    SCShowingResult = NO;
}