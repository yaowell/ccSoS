TARGET := iphone:clang:latest:15.0
INSTALL_ENDPOINT = 127.0.0.1 -p 2222

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SimpleCowbell

$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = UIKit CoreGraphics

# 移除 PRIVATE_FRAMEWORKS，避免 Linker 找不到 SDK 私有框架標頭
# $(TWEAK_NAME)_PRIVATE_FRAMEWORKS = ControlCenterUIKit ControlCenterUI

# 保留 RootHide / Dopamine 64 位頁面對齊參數
$(TWEAK_NAME)_LDFLAGS += -Wl,-segalign,0x4000

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
