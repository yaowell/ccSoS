#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CCUICAPackageView : UIView
@end


static void SCWriteLog(NSString *text) {

    NSString *path =
        @"/var/mobile/Documents/SimpleCowbell_CAPackage.txt";

    NSFileHandle *file =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (!file) {

        [text writeToFile:path
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];

        return;
    }

    [file seekToEndOfFile];

    NSData *data =
        [text dataUsingEncoding:NSUTF8StringEncoding];

    [file writeData:data];

    [file closeFile];
}


%hook CCUICAPackageView

- (void)layoutSubviews {

    %orig;


    NSMutableString *output =
        [NSMutableString string];


    [output appendFormat:
        @"\n========== CAPACKAGE ==========\n"];


    [output appendFormat:
        @"self class = %@\n",
        NSStringFromClass([self class])
    ];


    [output appendFormat:
        @"frame = %@\n",
        NSStringFromCGRect(self.frame)
    ];


    [output appendFormat:
        @"bounds = %@\n",
        NSStringFromCGRect(self.bounds)
    ];


    [output appendFormat:
        @"packageName = %@\n",
        [self respondsToSelector:@selector(packageName)]
        ? [self valueForKey:@"packageName"]
        : @"<no packageName>"
    ];


    /*
     * ========================================================
     * 父视图链
     * ========================================================
     */

    [output appendString:
        @"\n--- SUPERVIEW CHAIN ---\n"
    ];


    UIView *superview =
        self.superview;


    int level = 0;


    while (superview && level < 15) {

        [output appendFormat:
            @"[%d] %@ frame=%@\n",
            level,
            NSStringFromClass(
                [superview class]
            ),
            NSStringFromCGRect(
                superview.frame
            )
        ];


        superview =
            superview.superview;

        level++;
    }


    /*
     * ========================================================
     * UIResponder 响应链
     * ========================================================
     */

    [output appendString:
        @"\n--- RESPONDER CHAIN ---\n"
    ];


    UIResponder *responder =
        self.nextResponder;


    level = 0;


    while (responder && level < 20) {

        [output appendFormat:
            @"[%d] %@\n",
            level,
            NSStringFromClass(
                [responder class]
            )
        ];


        responder =
            responder.nextResponder;

        level++;
    }


    /*
     * ========================================================
     * 当前 View 的直接 subviews
     * ========================================================
     */

    [output appendString:
        @"\n--- SUBVIEWS ---\n"
    ];


    int index = 0;


    for (UIView *subview in self.subviews) {

        [output appendFormat:
            @"[%d] %@ frame=%@ tag=%ld\n",
            index,
            NSStringFromClass(
                [subview class]
            ),
            NSStringFromCGRect(
                subview.frame
            ),
            (long)subview.tag
        ];


        index++;
    }


    [output appendString:
        @"\n==============================\n"
    ];


    SCWriteLog(output);
}

%end