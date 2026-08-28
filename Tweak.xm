#import <UIKit/UIKit.h>

void writeDebugLog(NSString *text) {
    NSString *path = @"/var/mobile/cowbell_debug.txt";
    NSString *content = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], text];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

%hook CCUIRoundButton

- (void)layoutSubviews {
    %orig;
    writeDebugLog([NSString stringWithFormat:@"CCUIRoundButton layoutSubviews called! Parent: %@", NSStringFromClass([self.nextResponder class])]);
}

%end

%ctor {
    writeDebugLog(@"=== Tweak Loaded Successfully! ===");
}
