#import <Foundation/Foundation.h>

%ctor {

    NSString *path =
        @"/var/mobile/Documents/SimpleCowbell_Loaded.txt";

    NSString *text =
        @"SimpleCowbell dylib loaded successfully\n";

    [text writeToFile:path
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];
}