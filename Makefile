TARGET := iphone:clang:latest:15.0
INSTALL_ENDPOINT = 127.0.0.1 -p 2222

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SimpleCowbell

$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = UIKit CoreGraphics
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = ControlCenterUIKit ControlCenterUI

# 針對 RootHide / Dopamine 無根環境的旗標設定
$(TWEAK_NAME)_LDFLAGS += -Xtheos -Wl,-segalign,0x4000

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
