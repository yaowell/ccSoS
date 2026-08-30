THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SimpleCowbell

SimpleCowbell_FILES = Tweak.x
SimpleCowbell_CFLAGS = -fobjc-arc
SimpleCowbell_FRAMEWORKS = UIKit QuartzCore CoreGraphics
SimpleCowbell_STRIP = 1

include $(THEOS)/makefiles/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
