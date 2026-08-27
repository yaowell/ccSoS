TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CowbellBattery

CowbellBattery_FILES = Tweak.xm
CowbellBattery_CFLAGS = -fobjc-arc
CowbellBattery_FRAMEWORKS = UIKit
CowbellBattery_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
