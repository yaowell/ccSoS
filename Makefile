TARGET := iphone:clang:latest:15.0
INSTALL_ENDPOINT = 127.0.0.1 -p 2222

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SimpleCowbell

$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = UIKit CoreGraphics
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = ControlCenterUIKit ControlCenterUI

# 修正：移除 -Xtheos，保留 64 位页面对齐参数
$(TWEAK_NAME)_LDFLAGS += -Wl,-segalign,0x4000

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
