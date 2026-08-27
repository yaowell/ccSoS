TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = cowbellbattery

cowbellbattery_FILES = Tweak.xm
cowbellbattery_CFLAGS = -fobjc-arc
cowbellbattery_FRAMEWORKS = UIKit
cowbellbattery_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
