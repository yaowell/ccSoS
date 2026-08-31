#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUICAPackageView : UIView

@property (nonatomic, copy) NSString *packageName;

@end


static NSMutableSet *SCSeenPackages;


static void SCShowInfo(NSString *message) {

    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *window = nil;

        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *sceneWindow =
                (UIWindowScene *)scene;

            if (sceneWindow.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            for (UIWindow *w in sceneWindow.windows) {

                if (w.isKeyWindow) {
                    window = w;
                    break;
                }
            }

            if (window) {
                break;
            }
        }

        if (!window) {
            return;
        }

        UIViewController *vc =
            window.rootViewController;

        if (!vc) {
            return;
        }

        while (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }

        UIAlertController *alert =
            [UIAlertController
                alertControllerWithTitle:@"CAPackage 探针"
                message:message
                preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
            [UIAlertAction
                actionWithTitle:@"OK"
                style:UIAlertActionStyleDefault
                handler:nil]];

        [vc presentViewController:alert
                         animated:YES
                       completion:nil];
    });
}


%ctor {

    SCSeenPackages =
        [NSMutableSet set];
}


%hook CCUICAPackageView

- (void)layoutSubviews {

    %orig;


    NSString *packageName = nil;

    if ([self respondsToSelector:@selector(packageName)]) {

        packageName =
            [self valueForKey:@"packageName"];
    }


    if (!packageName) {
        packageName = @"<nil>";
    }


    /*
     * 同一个 package 只测试一次。
     */

    @synchronized (SCSeenPackages) {

        if ([SCSeenPackages containsObject:packageName]) {
            return;
        }

        if (SCSeenPackages.count >= 5) {
            return;
        }

        [SCSeenPackages addObject:packageName];
    }


    NSMutableString *info =
        [NSMutableString string];


    [info appendFormat:
        @"CLASS:\n%@\n\n",
        NSStringFromClass([self class])
    ];


    [info appendFormat:
        @"PACKAGE:\n%@\n\n",
        packageName
    ];


    [info appendFormat:
        @"FRAME:\n%@\n\n",
        NSStringFromCGRect(self.frame)
    ];


    [info appendFormat:
        @"BOUNDS:\n%@\n\n",
        NSStringFromCGRect(self.bounds)
    ];


    /*
     * =====================================================
     * Superview
     * =====================================================
     */

    [info appendString:
        @"SUPERVIEW:\n"
    ];


    UIView *superview =
        self.superview;


    NSInteger level = 0;


    while (superview && level < 8) {

        [info appendFormat:
            @"[%ld] %@\n",
            (long)level,
            NSStringFromClass(
                [superview class]
            )
        ];

        superview =
            superview.superview;

        level++;
    }


    /*
     * =====================================================
     * Subviews
     * =====================================================
     */

    [info appendString:
        @"\nSUBVIEWS:\n"
    ];


    NSInteger index = 0;


    for (UIView *subview in self.subviews) {

        [info appendFormat:
            @"[%ld] %@ frame=%@\n",
            (long)index,
            NSStringFromClass(
                [subview class]
            ),
            NSStringFromCGRect(
                subview.frame
            )
        ];

        index++;
    }


    /*
     * =====================================================
     * CALayer
     * =====================================================
     */

    [info appendString:
        @"\nLAYER:\n"
    ];


    [info appendFormat:
        @"layerClass = %@\n",
        NSStringFromClass(
            [self.layer class]
        )
    ];


    [info appendFormat:
        @"sublayers = %lu\n",
        (unsigned long)self.layer.sublayers.count
    ];


    /*
     * =====================================================
     * 显示
     * ===================================================== */

    SCShowInfo(info);
}

%end