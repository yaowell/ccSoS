- (void)willTransitionToExpandedContentMode:(BOOL)expanded {

    %orig(expanded);

    if (![self.moduleIdentifier
          isEqualToString:@"com.apple.control-center.LowPowerModule"]) {
        return;
    }

    if (!self.cowbellLabel) return;


    /*
     ============================================================
                        保存当前状态
     ============================================================
     */

    self.cowbellIsExpanded = expanded;


    /*
     ============================================================
                      切换一级 / 二级位置
     ============================================================
     */

    if (expanded) {

        // 一级 -> 二级

        self.cowbellCollapsedTopConstraint.active = NO;
        self.cowbellExpandedTopConstraint.active = YES;

    } else {

        // 二级 -> 一级

        self.cowbellExpandedTopConstraint.active = NO;
        self.cowbellCollapsedTopConstraint.active = YES;
    }


    UIView *container = self.cowbellLabel.superview;

    if (!container) return;


    /*
     ============================================================
                     一级 -> 二级
     ============================================================

     二级菜单：

         百分比隐藏

     ============================================================
     */

    if (expanded) {

        /*
         --------------------------------------------------------
         转场开始：

         先保持 Label 存在，只让它淡出。

         这样不会破坏你已经正常的同步效果。
         --------------------------------------------------------
         */

        self.cowbellLabel.hidden = NO;

        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:
             UIViewAnimationOptionBeginFromCurrentState |
             UIViewAnimationOptionAllowUserInteraction |
             UIViewAnimationOptionCurveEaseInOut
                         animations:^{

            [container layoutIfNeeded];

            self.cowbellLabel.alpha = 0.0;

        }
                         completion:^(BOOL finished) {

            /*
             ----------------------------------------------------
             动画结束以后强制隐藏。

             这一步非常重要。

             即使 iOS 后面重新 layout，
             Label 也不会在二级菜单里重新显示。
             ----------------------------------------------------
             */

            self.cowbellLabel.alpha = 0.0;
            self.cowbellLabel.hidden = YES;
        });


    } else {


        /*
         ========================================================
                       二级 -> 一级
         ========================================================

         关键：

         必须在动画开始之前先：

             hidden = NO
             alpha = 0

         然后跟着转场：

             0 -> 1

         这样不会出现：

             电池图标已经出来
             ↓
             百分比过一会才创建

         因为百分比实际上一直存在。
         ========================================================
         */


        self.cowbellLabel.hidden = NO;

        self.cowbellLabel.alpha = 0.0;


        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:
             UIViewAnimationOptionBeginFromCurrentState |
             UIViewAnimationOptionAllowUserInteraction |
             UIViewAnimationOptionCurveEaseInOut
                         animations:^{

            [container layoutIfNeeded];

            self.cowbellLabel.alpha = 1.0;

        }
                         completion:^(BOOL finished) {

            /*
             ----------------------------------------------------
             最终锁定一级状态
             ----------------------------------------------------
             */

            self.cowbellLabel.hidden = NO;
            self.cowbellLabel.alpha = 1.0;
        });
    }
}